extends Node2D

# ── EchoVeil: Mourk Weave — board & gameplay ──────────────────────────────────
#
# Two Dots-style rules, EchoVeil flavour:
#  · Drag through orthogonally adjacent shards of the same hue to weave a thread.
#  · Release with 2+ shards woven to gather them (costs one move).
#  · Weave back onto a shard already in the thread to close a LOOP — releasing
#    gathers every unveiled shard of that hue on the board.
#  · Veiled shards can't be woven; gathering beside a veil lifts it.
#  · Meet every goal before your moves run out.
#
# Mechanics introduced gradually across the threads (see G.LEVELS):
#  · RESONANT shards let a thread change hue and keep going.
#  · ECHO shards count down each move; at zero the Loops rewind their
#    neighbours' hues. Gather one in time for a bonus move.

const COLS := 6
const ROWS := 6
const CELL := 104.0
const PICK_RADIUS := CELL * 0.44

var level_def: Dictionary
var color_count := 3
var moves_left := 0
var goals := {}          # color index -> remaining motes to gather
var veils_left := 0

var res_chance := 0.0    # chance a spawned shard is resonant
var echo_count := 0      # echo shards maintained on the board
var wardens_left := 0    # Canvas drones still on the board
var warden_fuse := 0     # moves a drone waits before it scans
var thread_color := -1   # hue of the current thread (-1 = only resonants so far)
var switch_armed := false  # last woven shard was resonant: next may be any hue

const MIN_LOOP := 4          # distinct shards needed to close a loop
const CHAIN_RESONANT := 8    # chain this long and a new resonant shard forms
const FACET_MIN := 3         # shards in a straight diagonal run to make a facet

var board_origin := Vector2.ZERO   # centre of the top-left cell
var grid: Array = []               # grid[col][row] -> MourkDot or null (row 0 = top)
var dots_root: Node2D
var line_layer: Node2D

var path: Array[Vector2i] = []
var dragging := false
var loop_closed := false
var drag_pos := Vector2.ZERO
var busy := false
var game_over := false

var hud: CanvasLayer
var moves_label: Label
var goal_chips := {}     # key (color idx or "veils") -> GoalChip
var active_banner: Label


func _ready() -> void:
	randomize()
	level_def = G.LEVELS[G.current_level]
	color_count = level_def.colors
	moves_left = level_def.moves
	for k in level_def.goals:
		goals[k] = level_def.goals[k]
	veils_left = level_def.veils
	res_chance = level_def.get("resonance", 0.0)
	echo_count = level_def.get("echo", 0)
	wardens_left = level_def.get("wardens", 0)
	warden_fuse = level_def.get("fuse", MourkDot.WARDEN_FUSE)

	var vp := get_viewport_rect().size
	board_origin = Vector2(
		(vp.x - (COLS - 1) * CELL) * 0.5,
		vp.y * 0.33
	)

	_build_backdrop()
	line_layer = LineLayer.new(self)
	add_child(line_layer)
	dots_root = Node2D.new()
	add_child(dots_root)
	_build_hud(vp)
	_fill_board()
	_refresh_hud()
	# no sockets: shards hang in the veil, not in slots
	if level_def.has("note"):
		_show_banner(level_def.note, 4.5)


func _update_focus() -> void:
	# The thread is the hero: while weaving, everything that can't join it
	# falls back into the veil. Without this the board reads as a wall of gems.
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d == null:
				continue
			var target := 1.0
			var lock := false
			if dragging:
				if path.has(Vector2i(c, r)):
					target = 1.0
				elif not d.veiled and _may_weave(d):
					target = 0.82
					lock = d.warden      # strikeable right now
				else:
					target = 0.30
			if d.targetable != lock:
				d.targetable = lock
				d.queue_redraw()
			d.set_focus(target)


# ── Setup ─────────────────────────────────────────────────────────────────────

func _build_backdrop() -> void:
	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	var bg := ColorRect.new()
	bg.color = G.BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Critical: without this the full-screen rect consumes every touch
	# before it can reach the board's _unhandled_input.
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(bg)
	var motes := VeilMotes.new()
	motes.modulate = Color(1, 1, 1, 0.5)
	back.add_child(motes)


func _fill_board() -> void:
	grid.clear()
	for c in COLS:
		var col_arr := []
		col_arr.resize(ROWS)
		grid.append(col_arr)
	for c in COLS:
		for r in ROWS:
			_spawn_dot(Vector2i(c, r), _cell_pos(Vector2i(c, r)))
	# Shroud some motes behind veils (never a resonant shard).
	var cells: Array[Vector2i] = []
	for c in COLS:
		for r in ROWS:
			var vd: MourkDot = _dot_at(Vector2i(c, r))
			if not vd.resonant and not vd.warden:
				cells.append(Vector2i(c, r))
	cells.shuffle()
	for i in mini(level_def.veils, cells.size()):
		var d: MourkDot = _dot_at(cells[i])
		d.veiled = true
		d.queue_redraw()
	_place_wardens()
	_maintain_echoes()
	_ensure_move_exists()


func _spawn_dot(cell: Vector2i, pos: Vector2) -> MourkDot:
	var d := MourkDot.new()
	d.setup(randi() % color_count, cell)
	if randf() < res_chance:
		d.resonant = true
		d.queue_redraw()
	d.position = pos
	dots_root.add_child(d)
	grid[cell.x][cell.y] = d
	return d


func _place_wardens() -> void:
	# Never on the outer edge: a cornered drone is far too easy to reach.
	var spots: Array[Vector2i] = []
	for c in range(1, COLS - 1):
		for r in range(1, ROWS - 1):
			var d: MourkDot = _dot_at(Vector2i(c, r))
			if d != null and not d.veiled and not d.resonant:
				spots.append(Vector2i(c, r))
	spots.shuffle()
	for i in mini(wardens_left, spots.size()):
		var d: MourkDot = _dot_at(spots[i])
		d.warden = true
		d.veiled = false
		d.resonant = false
		d.echo_timer = 0
		d.warden_timer = warden_fuse + i            # stagger their fuses
		d.queue_redraw()


func _tick_wardens() -> void:
	# Each move burns a fuse. At zero the drone scans: it veils what is
	# around it, then starts over.
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d == null or not d.warden:
				continue
			d.warden_timer -= 1
			if d.warden_timer <= 0:
				_warden_fire(Vector2i(c, r))
				d.warden_timer = warden_fuse
			d.queue_redraw()


func _warden_fire(at: Vector2i) -> void:
	var hit := 0
	var around := _neighbours(at)
	around.shuffle()
	for n in around:
		if hit >= 3:
			break
		var nd: MourkDot = _dot_at(n)
		if nd != null and not nd.veiled and not nd.warden and not nd.resonant:
			nd.shroud()
			hit += 1
	_spawn_burst(_cell_pos(at), Color(1.0, 0.32, 0.26), 14, 120.0)


func _maintain_echoes() -> void:
	# Keep the thread's quota of echo shards ticking on the board.
	if echo_count <= 0:
		return
	var active := 0
	var candidates: Array = []
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d == null:
				continue
			if d.echo_timer > 0:
				active += 1
			elif not d.veiled and not d.resonant and not d.warden:
				candidates.append(d)
	candidates.shuffle()
	while active < echo_count and not candidates.is_empty():
		var d: MourkDot = candidates.pop_back()
		d.echo_timer = MourkDot.ECHO_START
		d.queue_redraw()
		active += 1


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if busy or game_over:
		return
	# Handle both touch and mouse: real devices send touch, desktop sends
	# mouse; both may arrive when emulation is on, so handlers are idempotent.
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventMouseMotion:
		_update_drag(event.position)


func _start_drag(pos: Vector2) -> void:
	if dragging:
		return
	var cell := _cell_at(pos)
	if cell.x < 0:
		return
	var d: MourkDot = _dot_at(cell)
	if d == null or d.veiled or d.warden:
		return          # a thread must start in Mourk, not on a drone
	dragging = true
	loop_closed = false
	path = [cell]
	_recompute_thread()
	drag_pos = pos
	d.bump()
	_update_focus()
	line_layer.queue_redraw()


func _update_drag(pos: Vector2) -> void:
	if not dragging:
		return
	drag_pos = pos
	var cell := _cell_at(pos)
	if cell.x >= 0 and not path.is_empty():
		var last: Vector2i = path[path.size() - 1]
		if cell != last:
			# Striking a warden ends the thread — only backtracking is left.
			if _ends_on_warden() and not (path.size() >= 2 and cell == path[path.size() - 2]):
				line_layer.queue_redraw()
				return
			if path.size() >= 2 and cell == path[path.size() - 2]:
				# Backtrack: unweave the last shard.
				path.pop_back()
				loop_closed = _path_has_repeat()
				_recompute_thread()
				_update_focus()
			elif not loop_closed and _adjacent(cell, last):
				var d: MourkDot = _dot_at(cell)
				if d != null and not d.veiled and _may_weave(d):
					# Closing a loop needs MIN_LOOP distinct shards. Without
					# this, diagonals would let three shards in an L close a
					# loop — and a loop clears the entire hue.
					var idx := path.find(cell)
					var closes := idx >= 0
					if closes and path.size() - idx < MIN_LOOP:
						line_layer.queue_redraw()
						return
					path.append(cell)
					_recompute_thread()
					d.bump()
					if closes:
						loop_closed = true
						_pulse_hue(thread_color)
					_update_focus()
	line_layer.queue_redraw()


func _end_drag() -> void:
	if not dragging:
		return
	dragging = false
	_update_focus()
	if path.size() < 2:
		path.clear()
		line_layer.queue_redraw()
		return
	var color := thread_color
	var was_loop := loop_closed
	var shape := _analyse_shape()
	var cells := {}
	if was_loop and color >= 0:
		# Loop: every unveiled, non-resonant shard of the thread's hue...
		for c in COLS:
			for r in ROWS:
				var d: MourkDot = grid[c][r]
				if d != null and not d.veiled and not d.resonant and not d.warden \
					and d.color_idx == color:
					cells[Vector2i(c, r)] = true
	# ...plus everything actually woven (covers resonants in the path).
	for cell in path:
		cells[cell] = true

	# Shape bonuses. A facet sends a shockwave out along both flanks of the
	# diagonal; a diamond collapses whatever it encircles, whatever hue it is.
	if shape.facet >= FACET_MIN:
		for c2 in _facet_flanks(shape.facet_at, shape.facet):
			var fd: MourkDot = _dot_at(c2)
			if fd != null and not fd.veiled:
				cells[c2] = true
	if shape.diamond:
		var cd: MourkDot = _dot_at(shape.centre)
		if cd != null and not cd.veiled:
			cells[shape.centre] = true

	var focus_pt := _cell_pos(path[path.size() - 1])
	path.clear()
	loop_closed = false
	_update_focus()
	line_layer.queue_redraw()
	_resolve(cells.keys(), color, was_loop, shape, focus_pt)


func _facet_flanks(start: int, run: int) -> Array[Vector2i]:
	# Cells either side of the ONE longest straight diagonal run.
	#
	# This used to flank every diagonal step anywhere in the path, so a long
	# zigzag threw off flanks across the whole board and a single move could
	# clear almost all 36 cells. The shockwave belongs to the straight run
	# only — that is what the shape actually is.
	var out: Array[Vector2i] = []
	if start < 0 or run < 2:
		return out
	var step: Vector2i = path[start + 1] - path[start]
	var perp := Vector2i(step.x, -step.y)
	for k in range(start, mini(start + run, path.size())):
		out.append(path[k] + perp)
		out.append(path[k] - perp)
	return out


# ── Resolution ────────────────────────────────────────────────────────────────

func _resolve(cells: Array, color: int, was_loop := false, shape := {},
		focus_pt := Vector2.ZERO) -> void:
	busy = true
	moves_left -= 1

	# Lift veils next to gathered motes.
	for cell in cells:
		for n in _neighbours(cell):
			var nd: MourkDot = _dot_at(n)
			if nd != null and nd.veiled:
				nd.unveil()
				veils_left -= 1

	# Count each shard toward its own hue: shape bonuses pull in shards the
	# thread never touched, so a bulk decrement against one hue would be wrong.
	for cell in cells:
		var d: MourkDot = _dot_at(cell)
		if d == null:
			continue
		if d.warden:
			wardens_left -= 1
			_spawn_burst(_cell_pos(cell), Color(1.0, 0.42, 0.32), 18, 175.0)
		elif goals.has(d.color_idx):
			goals[d.color_idx] = maxi(0, goals[d.color_idx] - 1)

	# Gathering an echo shard before its countdown ends grants a bonus move.
	for cell in cells:
		var d: MourkDot = _dot_at(cell)
		if d.echo_timer > 0:
			moves_left += 1
		grid[cell.x][cell.y] = null
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "scale", Vector2(1.6, 1.6), 0.16).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(d, "modulate", Color(1, 1, 1, 0), 0.16)
		tw.chain().tween_callback(d.queue_free)

	if not shape.is_empty():
		_celebrate_shape(shape, color, cells, focus_pt)

	_refresh_hud()
	await get_tree().create_timer(0.18).timeout
	await _collapse_and_refill()
	_tick_echoes()
	_maintain_echoes()
	_tick_wardens()

	# A long enough chain condenses a new resonance out of the gathered Mourk.
	if res_chance > 0.0 and cells.size() >= CHAIN_RESONANT:
		_form_resonant()

	if _goals_met():
		_finish(true)
	elif moves_left <= 0:
		_finish(false)
	else:
		_ensure_move_exists()
		busy = false


func _celebrate_shape(shape: Dictionary, color: int, cells: Array, focus_pt: Vector2) -> void:
	# Shapes stack, so a knotted diamond of facets pays out all three.
	var hue: Color = G.DOT_COLORS[color] if color >= 0 else Color(0.92, 0.94, 1.0)
	var centre := focus_pt
	if not cells.is_empty():
		centre = Vector2.ZERO
		for cell in cells:
			centre += _cell_pos(cell)
		centre /= float(cells.size())

	var title := ""
	if shape.facet >= FACET_MIN:
		title = "FACET"
		_spawn_burst(centre, hue, 10, 150.0)
	if shape.diamond:
		title = "DIAMOND"
		_spawn_burst(_cell_pos(shape.centre), hue, 16, 195.0)
	if shape.knot:
		# A true weave: the thread crossed itself. Worth a move back.
		title = "WEAVE"
		moves_left += 1
		_spawn_burst(centre, Color(0.92, 0.94, 1.0), 20, 225.0)

	if title != "":
		# Sits just above the board so it never lands on top of the burst.
		_show_banner(title, 1.0, hue.lightened(0.3), 40, board_origin.y - 96.0)


func _spawn_burst(at: Vector2, col: Color, rays: int, radius: float) -> void:
	var b := Burst.new()
	b.position = at
	b.col = col
	b.rays = rays
	b.max_radius = radius
	add_child(b)


func _form_resonant() -> void:
	var candidates: Array = []
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d != null and not d.veiled and not d.resonant and not d.warden \
				and d.echo_timer <= 0:
				candidates.append(d)
	if candidates.is_empty():
		return
	var d: MourkDot = candidates[randi() % candidates.size()]
	d.resonant = true
	d.queue_redraw()
	d.bump()
	_show_banner("RESONANCE", 1.2, Color(0.92, 0.94, 1.0), 32,
		board_origin.y + (ROWS - 1) * CELL * 0.5 - 24.0)


func _tick_echoes() -> void:
	# Echo shards count down each move; at zero the Loop rewinds their
	# neighbours' hues, then the countdown starts again.
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d == null or d.echo_timer <= 0 or d.veiled:
				continue
			d.echo_timer -= 1
			if d.echo_timer <= 0:
				for n in _neighbours(Vector2i(c, r)):
					var nd: MourkDot = _dot_at(n)
					if nd != null and not nd.veiled and not nd.resonant:
						nd.color_idx = randi() % color_count
						nd.queue_redraw()
						nd.bump()
				d.echo_timer = MourkDot.ECHO_START
			d.queue_redraw()


func _collapse_and_refill() -> void:
	var fall_time := 0.24
	for c in COLS:
		var survivors: Array = []
		for r in ROWS:
			if grid[c][r] != null:
				survivors.append(grid[c][r])
		var missing := ROWS - survivors.size()
		# Re-seat survivors from the bottom of the column.
		for i in survivors.size():
			var new_row: int = missing + i
			var d: MourkDot = survivors[i]
			grid[c][new_row] = d
			if d.cell.y != new_row:
				d.cell = Vector2i(c, new_row)
				var tw := create_tween()
				tw.tween_property(d, "position", _cell_pos(d.cell), fall_time) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for r in missing:
			grid[c][r] = null
		# Drop fresh motes in from above the veil.
		for r in missing:
			var cell := Vector2i(c, r)
			var start := _cell_pos(cell) - Vector2(0, CELL * (missing - r + 1) + 40.0)
			var d := _spawn_dot(cell, start)
			var tw := create_tween()
			tw.tween_property(d, "position", _cell_pos(cell), fall_time + 0.06) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(fall_time + 0.10).timeout


func _ensure_move_exists() -> void:
	# If no two adjacent unveiled motes share a hue, the veil reshuffles itself.
	for attempt in 30:
		if _has_move():
			return
		for c in COLS:
			for r in ROWS:
				var d: MourkDot = grid[c][r]
				if d != null and not d.veiled and not d.warden:
					d.color_idx = randi() % color_count
					d.queue_redraw()


func _has_move() -> bool:
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d == null or d.veiled or d.warden:
				continue
			for n in _neighbours(Vector2i(c, r)):
				var nd: MourkDot = _dot_at(n)
				if nd != null and not nd.veiled and not nd.warden \
					and (nd.resonant or d.resonant or nd.color_idx == d.color_idx):
					return true
	return false


func _goals_met() -> bool:
	for k in goals:
		if goals[k] > 0:
			return false
	return veils_left <= 0 and wardens_left <= 0


# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud(vp: Vector2) -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var back := UIH.make_button("‹", 30, Color(0.6, 0.64, 0.76))
	back.position = Vector2(20, 24)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))
	hud.add_child(back)

	var lvl := UIH.make_label("THREAD %d" % (G.current_level + 1), 26, Color(0.55, 0.58, 0.70))
	lvl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lvl.position.y = 36
	hud.add_child(lvl)

	moves_label = UIH.make_label(str(moves_left), 64, G.GOLD)
	moves_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	moves_label.position.y = 78
	hud.add_child(moves_label)

	var moves_cap := UIH.make_label("MOVES", 20, Color(0.55, 0.58, 0.70))
	moves_cap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	moves_cap.position.y = 152
	hud.add_child(moves_cap)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 22)
	chips.set_anchors_preset(Control.PRESET_TOP_WIDE)
	chips.position.y = 200
	hud.add_child(chips)

	for k in goals:
		var chip := GoalChip.new(k, false, false, int(goals[k]))
		chips.add_child(chip)
		goal_chips[k] = chip
	if level_def.veils > 0:
		var vchip := GoalChip.new(0, true, false, level_def.veils)
		chips.add_child(vchip)
		goal_chips["veils"] = vchip
	if level_def.get("wardens", 0) > 0:
		var wchip := GoalChip.new(0, false, true, level_def.get("wardens", 0))
		chips.add_child(wchip)
		goal_chips["wardens"] = wchip

	var hint := UIH.make_label("Weave any direction. Close a loop to gather a whole hue.", 20, Color(0.42, 0.46, 0.58))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position.y = -70
	hud.add_child(hint)


func _show_banner(text: String, dur: float, color := G.GOLD, font_size := 24,
		y := -1.0) -> void:
	# Notes sit in the clear space below the board; alerts are passed a y
	# over the board itself. Never covers the shards either way.
	# Only ever one banner on screen, so an alert can't stack on a note.
	if is_instance_valid(active_banner):
		active_banner.queue_free()
	var top: float = y if y >= 0.0 else board_origin.y + (ROWS - 1) * CELL + 78.0
	var banner := UIH.make_label(text, font_size, color)
	active_banner = banner
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Offsets only — assigning `position` would preserve width and undo the
	# side margins, leaving the text unwrapped and running off-screen.
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_left = 44.0
	banner.offset_right = -44.0
	banner.offset_top = top
	banner.offset_bottom = top + font_size * 3.2
	hud.add_child(banner)
	banner.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(banner, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.tween_interval(dur)
	tw.tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.tween_callback(banner.queue_free)


func _refresh_hud() -> void:
	moves_label.text = str(maxi(moves_left, 0))
	for k in goal_chips:
		# Keys are either a hue index or a name; comparing an int against a
		# String is a hard error in GDScript, so branch on the type first.
		if k is String:
			if k == "veils":
				goal_chips[k].set_remaining(maxi(veils_left, 0))
			else:
				goal_chips[k].set_remaining(maxi(wardens_left, 0))
		else:
			goal_chips[k].set_remaining(goals[k])


# ── End of level ──────────────────────────────────────────────────────────────

func _finish(won: bool) -> void:
	game_over = true
	busy = true
	if won:
		G.unlock_through(G.current_level)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)

	var title := UIH.make_label("VEIL  LIFTED" if won else "THE  VEIL  HOLDS", 54,
		G.GOLD if won else Color(0.75, 0.45, 0.45))
	vbox.add_child(title)

	var flavor := "The Mourk remembers what you gathered." if won \
		else "Feeling faded before the weave was done."
	vbox.add_child(UIH.make_label(flavor, 24, Color(0.6, 0.64, 0.76)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	if won and G.current_level + 1 < G.level_count():
		var next := UIH.make_button("NEXT  THREAD", 32)
		next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next.pressed.connect(func() -> void:
			G.current_level += 1
			get_tree().reload_current_scene())
		buttons.add_child(next)
	var retry := UIH.make_button("WEAVE  AGAIN" if not won else "REWEAVE", 32 if not won else 26)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(func() -> void:
		get_tree().reload_current_scene())
	buttons.add_child(retry)
	var menu := UIH.make_button("THREADS", 26, Color(0.6, 0.64, 0.76))
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn"))
	buttons.add_child(menu)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(vbox)
	layer.add_child(center)

	center.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(center, "modulate", Color(1, 1, 1, 1), 0.35)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _cell_pos(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x, cell.y) * CELL


func _cell_at(pos: Vector2) -> Vector2i:
	var rel := pos - board_origin
	var c := int(roundf(rel.x / CELL))
	var r := int(roundf(rel.y / CELL))
	if c < 0 or c >= COLS or r < 0 or r >= ROWS:
		return Vector2i(-1, -1)
	if pos.distance_to(_cell_pos(Vector2i(c, r))) > PICK_RADIUS:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


func _dot_at(cell: Vector2i) -> MourkDot:
	if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
		return null
	return grid[cell.x][cell.y]


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	# 8-way: threads may run diagonally.
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return maxi(dx, dy) == 1 and (dx + dy) > 0


func _neighbours(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				out.append(Vector2i(cell.x + dx, cell.y + dy))
	return out


func _analyse_shape() -> Dictionary:
	# Reads the woven path for the three shapes diagonals make possible.
	#   facet   — longest straight diagonal run, in shards
	#   diamond — the closed loop is a 4-shard rhombus around a centre
	#   knot    — two diagonal segments cross each other: a true weave
	var out := { "facet": 0, "facet_at": -1, "diamond": false, "knot": false,
		"centre": Vector2i.ZERO }
	if path.size() < 2:
		return out

	# Longest straight diagonal run.
	var best := 0
	var i := 0
	while i < path.size() - 1:
		var step: Vector2i = path[i + 1] - path[i]
		if step.x == 0 or step.y == 0:
			i += 1
			continue
		var run := 2
		var j := i + 1
		while j < path.size() - 1 and (path[j + 1] - path[j]) == step:
			run += 1
			j += 1
		if run > best:
			best = run
			out.facet_at = i
		i = j
	out.facet = best

	# Diamond: a closed 4-shard loop whose centroid is a cell, each shard one
	# orthogonal step from it. A 2x2 square centres between cells, so it can
	# never match — square and diamond stay distinct shapes.
	if loop_closed:
		var idx := path.find(path[path.size() - 1])
		var loop: Array = path.slice(idx, path.size() - 1)
		if loop.size() == 4:
			var sum := Vector2i.ZERO
			for cell in loop:
				sum += cell
			if sum.x % 4 == 0 and sum.y % 4 == 0:
				var centre := Vector2i(sum.x / 4, sum.y / 4)
				var ok := true
				for cell in loop:
					var d: Vector2i = cell - centre
					if absi(d.x) + absi(d.y) != 1:
						ok = false
						break
				if ok:
					out.diamond = true
					out.centre = centre

	# Knot: two diagonal segments sharing a midpoint are the two diagonals of
	# one cell square, so the thread crosses itself.
	for a in range(path.size() - 1):
		var sa: Vector2i = path[a + 1] - path[a]
		if sa.x == 0 or sa.y == 0:
			continue
		for b in range(a + 1, path.size() - 1):
			var sb: Vector2i = path[b + 1] - path[b]
			if sb.x == 0 or sb.y == 0:
				continue
			if path[a] + path[a + 1] == path[b] + path[b + 1] \
				and path[a] != path[b] and path[a] != path[b + 1]:
				out.knot = true
				break
		if out.knot:
			break
	return out


func _may_weave(d: MourkDot) -> bool:
	# A warden is not gathered, it is struck: only ever as the final shard of
	# a thread that already has real Mourk in it. That is the whole decision —
	# spend a thread putting a drone down, or take the fat chain elsewhere.
	if d.warden:
		return path.size() >= 2 and not _ends_on_warden()
	if d.resonant:
		return true
	return thread_color < 0 or d.color_idx == thread_color or switch_armed


func _ends_on_warden() -> bool:
	if path.is_empty():
		return false
	var d: MourkDot = _dot_at(path[path.size() - 1])
	return d != null and d.warden


func _recompute_thread() -> void:
	# Derive thread hue and switch state from the path, so backtracking
	# restores the previous state for free.
	thread_color = -1
	switch_armed = false
	for cell in path:
		var d: MourkDot = _dot_at(cell)
		if d == null:
			continue
		if d.resonant:
			switch_armed = true
		else:
			thread_color = d.color_idx
			switch_armed = false


func _path_has_repeat() -> bool:
	var seen := {}
	for cell in path:
		if seen.has(cell):
			return true
		seen[cell] = true
	return false


func _pulse_hue(color: int) -> void:
	if color < 0:
		return
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d != null and not d.veiled and not d.resonant and d.color_idx == color:
				d.bump()


# ── Inner classes ─────────────────────────────────────────────────────────────

class LineLayer extends Node2D:
	var game

	func _init(p_game) -> void:
		game = p_game

	const RESONANT_COL := Color(0.92, 0.94, 1.0)

	func _draw() -> void:
		if game.path.is_empty():
			return
		# Per-point hue: the thread is drawn segment by segment so a switch
		# through a resonance is visible as the colour changing mid-thread.
		var pts := PackedVector2Array()
		var cols: Array[Color] = []
		var cur := -1
		for cell in game.path:
			pts.append(game._cell_pos(cell))
			var d = game._dot_at(cell)
			if d == null:
				cols.append(RESONANT_COL)
			elif d.resonant:
				cols.append(RESONANT_COL)
			else:
				cur = d.color_idx
				cols.append(G.DOT_COLORS[cur].lightened(0.2))
		if game.dragging:
			pts.append(game.drag_pos)
			cols.append(RESONANT_COL if game.switch_armed or cur < 0
				else G.DOT_COLORS[cur].lightened(0.2))

		var core_a := 0.95 if game.loop_closed else 0.8
		var aura_a := 0.35 if game.loop_closed else 0.22
		for i in range(pts.size() - 1):
			var seg := PackedVector2Array([pts[i], pts[i + 1]])
			var c: Color = cols[i + 1]
			var aura := c
			aura.a = aura_a
			draw_polyline(seg, aura, 26.0, true)
			c.a = core_a
			draw_polyline(seg, c, 8.0, true)
		for i in pts.size():
			draw_circle(pts[i], 6.0, cols[i])
		# Live chain counter beside the thread's head — long chains form a
		# resonance, so the player needs to see the count climbing.
		if game.path.size() >= 3:
			var head: Vector2 = pts[pts.size() - 1]
			var label := str(game.path.size())
			if game.path.size() >= game.CHAIN_RESONANT:
				label += "  ✦"
			draw_string(ThemeDB.fallback_font, head + Vector2(20, -18), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.92))



class Burst extends Node2D:
	# Shape payoff: a shockwave ring with light radiating out of it.
	var col := Color.WHITE
	var rays := 12
	var max_radius := 150.0
	var dur := 0.55
	var _t := 0.0
	var _spin := 0.0
	var _len: Array[float] = []
	var _wob: Array[float] = []
	var _base: Array[float] = []

	func _ready() -> void:
		_spin = randf() * TAU
		z_index = 40
		# Uneven splinters read as shattering crystal; evenly spaced lines of
		# equal length read as a radar sweep.
		for i in rays:
			_len.append(randf_range(0.62, 1.0))
			_wob.append(randf_range(-0.09, 0.09))
			_base.append(randf_range(0.55, 0.9))
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta / dur
		if _t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - _t, 3.0)   # fast out, slow settle
		var fade := 1.0 - _t
		var r := 18.0 + e * max_radius

		# Broken shockwave arcs rather than a closed ring: a full circle with
		# spokes inside it reads as a wheel, however thin it is drawn.
		var ring := col.lightened(0.4)
		ring.a = fade * fade * 0.55
		for k in 3:
			var a0 := _spin * 1.3 + TAU * float(k) / 3.0 + e * 0.5
			draw_arc(Vector2.ZERO, r, a0, a0 + 1.15, 20, ring, 1.0 + 3.0 * fade)

		# Crystal splinters thrown outward, tapering to a point.
		for i in rays:
			var ang := TAU * float(i) / float(rays) + _spin + _wob[i] + e * 0.3
			var dir := Vector2(cos(ang), sin(ang))
			var side := Vector2(-dir.y, dir.x)
			var tip: Vector2 = dir * (r * _len[i] * 1.35)
			var base: Vector2 = dir * (r * _len[i] * _base[i])
			var w: float = (2.6 * fade + 0.5)
			var shard := col.lightened(0.25)
			shard.a = fade * 0.7
			draw_colored_polygon(
				PackedVector2Array([tip, base + side * w, base - side * w]), shard)

		# White-hot core that collapses as the wave leaves.
		var core := col.lightened(0.65)
		core.a = fade * fade * 0.85
		draw_circle(Vector2.ZERO, 15.0 * fade, core)


class GoalChip extends Control:
	# Card treatment and "gathered / target" progress, per the UI design.
	# Showing progress rather than a bare remaining count means the number
	# always reads in the same direction as the goal.
	var color_idx := 0
	var is_veil := false
	var is_warden := false
	var remaining := 0
	var target := 0

	func _init(p_color_idx: int, p_veil: bool, p_warden := false, p_target := 0) -> void:
		color_idx = p_color_idx
		is_veil = p_veil
		is_warden = p_warden
		target = maxi(p_target, 0)
		remaining = target
		custom_minimum_size = Vector2(76, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_remaining(n: int) -> void:
		remaining = n
		queue_redraw()

	func _draw() -> void:
		# Card behind the chip.
		var card := Rect2(0, 0, size.x, size.y)
		draw_rect(card, TH.SURFACE)
		_draw_round_border(card, 12.0)

		var center := Vector2(size.x * 0.5, 34.0)
		var art := 52.0
		var rect := Rect2(center.x - art * 0.5, center.y - art * 0.5, art, art)
		if is_warden:
			# Same machined plate as the board piece, so the chip is obviously
			# a count of the drones rather than another hue.
			var box := StyleBoxFlat.new()
			box.bg_color = TH.WARDEN_BODY
			box.border_color = Color(TH.WARDEN_EYE.r, TH.WARDEN_EYE.g,
				TH.WARDEN_EYE.b, 0.45)
			box.set_border_width_all(2)
			box.set_corner_radius_all(12)
			draw_style_box(box, Rect2(center.x - 24.0, center.y - 24.0, 48.0, 48.0))
			draw_circle(center, 13.0, Color(TH.WARDEN_EYE.r, TH.WARDEN_EYE.g,
				TH.WARDEN_EYE.b, 0.35))
			draw_circle(center, 8.0, TH.WARDEN_EYE)
		elif is_veil:
			var tex: Texture2D = G.SHARD_TEXTURES[color_idx]
			draw_texture_rect(tex, rect, false, Color(0.40, 0.42, 0.52, 0.85))
			draw_arc(center, 26.0, 0.0, TAU, 32, G.VEIL_COLOR, 3.0)
		else:
			var glow: Color = G.DOT_COLORS[color_idx]
			glow.a = 0.18
			draw_circle(center, 30.0, glow)
			draw_texture_rect(G.SHARD_TEXTURES[color_idx], rect, false)
		var done := remaining <= 0
		var got: int = target - remaining
		var txt := "%d/%d" % [got, target]
		var txt_col: Color = Color("#5CEB7A") if done else TH.TEXT_PRIMARY
		draw_string(TH.FONT_BOLD, Vector2(0, 82), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, txt_col)

	func _draw_round_border(r: Rect2, rad: float) -> void:
		var pts := PackedVector2Array()
		var corners := [
			[Vector2(r.position.x + rad, r.position.y + rad), PI, 1.5 * PI],
			[Vector2(r.end.x - rad, r.position.y + rad), 1.5 * PI, TAU],
			[Vector2(r.end.x - rad, r.end.y - rad), 0.0, 0.5 * PI],
			[Vector2(r.position.x + rad, r.end.y - rad), 0.5 * PI, PI],
		]
		for c in corners:
			for i in 7:
				var a: float = lerpf(c[1], c[2], float(i) / 6.0)
				pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
		pts.append(pts[0])
		draw_polyline(pts, TH.HAIRLINE, 1.5, true)
