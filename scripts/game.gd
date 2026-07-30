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
#  · EXPOSURE — gathering draws Canvas attention; loops draw much more. At
#    capacity the Canvas sweeps the board and shrouds shards.
#  · RESONANT shards join a thread of any hue.
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

# Canvas attention: gathering raises Exposure; at capacity the Canvas scans
# the board and veils shards. 0 capacity = mechanic off for this thread.
var exposure := 0
var exposure_max := 0
const SCAN_VEILS := 3
const LOOP_EXPOSURE := 6

var res_chance := 0.0    # chance a spawned shard is resonant
var echo_count := 0      # echo shards maintained on the board
var thread_color := -1   # hue of the current thread (-1 = only resonants so far)
var switch_armed := false  # last woven shard was resonant: next may be any hue

const MIN_LOOP := 4          # distinct shards needed to close a loop
const CHAIN_RESONANT := 8    # chain this long and a new resonant shard forms

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
var exposure_bar: ExposureBar
var active_banner: Label


func _ready() -> void:
	randomize()
	level_def = G.LEVELS[G.current_level]
	color_count = level_def.colors
	moves_left = level_def.moves
	for k in level_def.goals:
		goals[k] = level_def.goals[k]
	veils_left = level_def.veils
	exposure_max = level_def.get("exposure", 0)
	res_chance = level_def.get("resonance", 0.0)
	echo_count = level_def.get("echo", 0)

	var vp := get_viewport_rect().size
	board_origin = Vector2(
		(vp.x - (COLS - 1) * CELL) * 0.5,
		vp.y * 0.36
	)

	_build_backdrop()
	line_layer = LineLayer.new(self)
	add_child(line_layer)
	dots_root = Node2D.new()
	add_child(dots_root)
	_build_hud(vp)
	_fill_board()
	_refresh_hud()
	queue_redraw()   # cell sockets
	if level_def.has("note"):
		_show_banner(level_def.note, 4.5)


func _draw() -> void:
	# Etched sockets beneath the shards — the veil's loom.
	for c in COLS:
		for r in ROWS:
			var p := _cell_pos(Vector2i(c, r))
			draw_arc(p, CELL * 0.44, 0.0, TAU, 40, Color(0.30, 0.34, 0.46, 0.16), 2.0)
			draw_circle(p, 2.0, Color(0.30, 0.34, 0.46, 0.22))


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
			if not _dot_at(Vector2i(c, r)).resonant:
				cells.append(Vector2i(c, r))
	cells.shuffle()
	for i in mini(level_def.veils, cells.size()):
		var d: MourkDot = _dot_at(cells[i])
		d.veiled = true
		d.queue_redraw()
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
			elif not d.veiled and not d.resonant:
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
	if d == null or d.veiled:
		return
	dragging = true
	loop_closed = false
	path = [cell]
	_recompute_thread()
	drag_pos = pos
	d.bump()
	line_layer.queue_redraw()


func _update_drag(pos: Vector2) -> void:
	if not dragging:
		return
	drag_pos = pos
	var cell := _cell_at(pos)
	if cell.x >= 0 and not path.is_empty():
		var last: Vector2i = path[path.size() - 1]
		if cell != last:
			if path.size() >= 2 and cell == path[path.size() - 2]:
				# Backtrack: unweave the last shard.
				path.pop_back()
				loop_closed = _path_has_repeat()
				_recompute_thread()
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
	line_layer.queue_redraw()


func _end_drag() -> void:
	if not dragging:
		return
	dragging = false
	if path.size() < 2:
		path.clear()
		line_layer.queue_redraw()
		return
	var color := thread_color
	var was_loop := loop_closed
	var cells := {}
	if was_loop and color >= 0:
		# Loop: every unveiled, non-resonant shard of the thread's hue...
		for c in COLS:
			for r in ROWS:
				var d: MourkDot = grid[c][r]
				if d != null and not d.veiled and not d.resonant and d.color_idx == color:
					cells[Vector2i(c, r)] = true
	# ...plus everything actually woven (covers resonants in the path).
	for cell in path:
		cells[cell] = true
	path.clear()
	loop_closed = false
	line_layer.queue_redraw()
	_resolve(cells.keys(), color, was_loop)


# ── Resolution ────────────────────────────────────────────────────────────────

func _resolve(cells: Array, color: int, was_loop := false) -> void:
	busy = true
	moves_left -= 1

	# Lift veils next to gathered motes.
	for cell in cells:
		for n in _neighbours(cell):
			var nd: MourkDot = _dot_at(n)
			if nd != null and nd.veiled:
				nd.unveil()
				veils_left -= 1

	# Count toward the hue goal and clear the motes. Gathering an echo shard
	# before its countdown ends grants a bonus move.
	if goals.has(color):
		goals[color] = maxi(0, goals[color] - cells.size())
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

	# The Canvas notices. Loops are loud.
	if exposure_max > 0:
		exposure += cells.size() + (LOOP_EXPOSURE if was_loop else 0)

	_refresh_hud()
	await get_tree().create_timer(0.18).timeout
	await _collapse_and_refill()
	_tick_echoes()
	_maintain_echoes()

	# A long enough chain condenses a new resonance out of the gathered Mourk.
	if res_chance > 0.0 and cells.size() >= CHAIN_RESONANT:
		_form_resonant()

	if exposure_max > 0 and exposure >= exposure_max:
		await _canvas_scan()

	if _goals_met():
		_finish(true)
	elif moves_left <= 0:
		_finish(false)
	else:
		_ensure_move_exists()
		busy = false


func _form_resonant() -> void:
	var candidates: Array = []
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d != null and not d.veiled and not d.resonant and d.echo_timer <= 0:
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


func _canvas_scan() -> void:
	# A Canvas sweep rakes the board and veils shards. Exposure resets.
	exposure = 0
	_show_banner("CANVAS SCAN", 1.4, Color(1.0, 0.42, 0.38), 44,
		board_origin.y + (ROWS - 1) * CELL * 0.5 - 30.0)

	var sweep := ScanSweep.new()
	sweep.width = get_viewport_rect().size.x
	sweep.position = Vector2(0, board_origin.y - CELL)
	add_child(sweep)
	var tw := create_tween()
	tw.tween_property(sweep, "position:y", board_origin.y + ROWS * CELL, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(sweep.queue_free)
	await get_tree().create_timer(0.6).timeout

	var candidates: Array = []
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d != null and not d.veiled and d.echo_timer <= 0:
				candidates.append(d)
	candidates.shuffle()
	for i in mini(SCAN_VEILS, candidates.size()):
		candidates[i].shroud()
	_refresh_hud()
	await get_tree().create_timer(0.25).timeout


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
				if d != null and not d.veiled:
					d.color_idx = randi() % color_count
					d.queue_redraw()


func _has_move() -> bool:
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d == null or d.veiled:
				continue
			for n in _neighbours(Vector2i(c, r)):
				var nd: MourkDot = _dot_at(n)
				if nd != null and not nd.veiled \
					and (nd.resonant or d.resonant or nd.color_idx == d.color_idx):
					return true
	return false


func _goals_met() -> bool:
	for k in goals:
		if goals[k] > 0:
			return false
	return veils_left <= 0


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
		var chip := GoalChip.new(k, false)
		chips.add_child(chip)
		goal_chips[k] = chip
	if level_def.veils > 0:
		var vchip := GoalChip.new(0, true)
		chips.add_child(vchip)
		goal_chips["veils"] = vchip

	if exposure_max > 0:
		exposure_bar = ExposureBar.new(self)
		exposure_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		exposure_bar.position.y = 306
		exposure_bar.custom_minimum_size = Vector2(0, 46)
		hud.add_child(exposure_bar)

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
		if k is String:
			goal_chips[k].set_remaining(maxi(veils_left, 0))
		else:
			goal_chips[k].set_remaining(goals[k])
	if exposure_bar != null:
		exposure_bar.queue_redraw()


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


func _may_weave(d: MourkDot) -> bool:
	# Resonant shards always join. A normal shard joins if it matches the
	# thread's hue, starts it, or follows a resonant — which lets the thread
	# switch hue and keep going.
	if d.resonant:
		return true
	return thread_color < 0 or d.color_idx == thread_color or switch_armed


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


class ScanSweep extends Node2D:
	# The Canvas raking the board: a red scanning beam.
	var width := 720.0

	func _draw() -> void:
		draw_rect(Rect2(0, -14, width, 28), Color(1.0, 0.30, 0.25, 0.10))
		draw_rect(Rect2(0, -3, width, 6), Color(1.0, 0.42, 0.35, 0.75))


class ExposureBar extends Control:
	# Canvas attention meter: fills gold -> red; full = scan.
	var game

	func _init(p_game) -> void:
		game = p_game
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var bar_w := 320.0
		var bar_h := 14.0
		var x := (size.x - bar_w) * 0.5
		var y := 24.0
		var pct: float = clampf(float(game.exposure) / float(game.exposure_max), 0.0, 1.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, 16), "EXPOSURE", HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 16, Color(0.55, 0.58, 0.70))
		# Slot
		draw_rect(Rect2(x, y, bar_w, bar_h), Color(0.07, 0.10, 0.17))
		draw_rect(Rect2(x, y, bar_w, bar_h), Color(0.30, 0.34, 0.46, 0.6), false, 1.5)
		# Fill
		if pct > 0.0:
			var fill := G.GOLD.lerp(Color(1.0, 0.35, 0.28), pct)
			draw_rect(Rect2(x + 2, y + 2, (bar_w - 4) * pct, bar_h - 4), fill)
		# The eye of the Canvas, brightening as it takes interest.
		var eye := Color(0.35, 0.38, 0.50).lerp(Color(1.0, 0.42, 0.35), pct)
		draw_circle(Vector2(x + bar_w + 22, y + bar_h * 0.5), 7.0, eye)
		draw_arc(Vector2(x + bar_w + 22, y + bar_h * 0.5), 11.0, 0.0, TAU, 24, eye, 1.5)


class GoalChip extends Control:
	var color_idx := 0
	var is_veil := false
	var remaining := 0

	func _init(p_color_idx: int, p_veil: bool) -> void:
		color_idx = p_color_idx
		is_veil = p_veil
		custom_minimum_size = Vector2(76, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_remaining(n: int) -> void:
		remaining = n
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, 32.0)
		var art := 58.0
		var rect := Rect2(center.x - art * 0.5, center.y - art * 0.5, art, art)
		if is_veil:
			var tex: Texture2D = G.SHARD_TEXTURES[color_idx]
			draw_texture_rect(tex, rect, false, Color(0.40, 0.42, 0.52, 0.85))
			draw_arc(center, 26.0, 0.0, TAU, 32, G.VEIL_COLOR, 3.0)
		else:
			var glow: Color = G.DOT_COLORS[color_idx]
			glow.a = 0.18
			draw_circle(center, 30.0, glow)
			draw_texture_rect(G.SHARD_TEXTURES[color_idx], rect, false)
		var done := remaining <= 0
		var txt := "OK" if done else str(remaining)
		var txt_col := Color(0.36, 0.92, 0.48) if done else Color(0.92, 0.93, 0.97)
		draw_string(ThemeDB.fallback_font, Vector2(0, 88), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, txt_col)
