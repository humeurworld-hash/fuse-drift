extends Node2D

# ── EchoVeil: Mourk Weave — board & gameplay ──────────────────────────────────
#
# Two Dots-style rules, EchoVeil flavour:
#  · Drag through orthogonally adjacent motes of the same hue to weave a thread.
#  · Release with 2+ motes woven to gather them (costs one move).
#  · Weave back onto a mote already in the thread to close a LOOP — releasing
#    gathers every unveiled mote of that hue on the board.
#  · Veiled motes can't be woven; gathering a mote next to a veil lifts it.
#  · Meet every goal before your moves run out.

const COLS := 6
const ROWS := 6
const CELL := 104.0
const PICK_RADIUS := CELL * 0.44

var level_def: Dictionary
var color_count := 3
var moves_left := 0
var goals := {}          # color index -> remaining motes to gather
var veils_left := 0

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


func _ready() -> void:
	randomize()
	level_def = G.LEVELS[G.current_level]
	color_count = level_def.colors
	moves_left = level_def.moves
	for k in level_def.goals:
		goals[k] = level_def.goals[k]
	veils_left = level_def.veils

	var vp := get_viewport_rect().size
	board_origin = Vector2(
		(vp.x - (COLS - 1) * CELL) * 0.5,
		vp.y * 0.34
	)

	_build_backdrop()
	line_layer = LineLayer.new(self)
	add_child(line_layer)
	dots_root = Node2D.new()
	add_child(dots_root)
	_build_hud(vp)
	_fill_board()
	_refresh_hud()


# ── Setup ─────────────────────────────────────────────────────────────────────

func _build_backdrop() -> void:
	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	var bg := ColorRect.new()
	bg.color = G.BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	# Shroud some motes behind veils.
	var cells: Array[Vector2i] = []
	for c in COLS:
		for r in ROWS:
			cells.append(Vector2i(c, r))
	cells.shuffle()
	for i in mini(level_def.veils, cells.size()):
		var d: MourkDot = _dot_at(cells[i])
		d.veiled = true
		d.queue_redraw()
	_ensure_move_exists()


func _spawn_dot(cell: Vector2i, pos: Vector2) -> MourkDot:
	var d := MourkDot.new()
	d.setup(randi() % color_count, cell)
	d.position = pos
	dots_root.add_child(d)
	grid[cell.x][cell.y] = d
	return d


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if busy or game_over:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventScreenDrag:
		_update_drag(event.position)


func _start_drag(pos: Vector2) -> void:
	var cell := _cell_at(pos)
	if cell.x < 0:
		return
	var d: MourkDot = _dot_at(cell)
	if d == null or d.veiled:
		return
	dragging = true
	loop_closed = false
	path = [cell]
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
				# Backtrack: unweave the last mote.
				path.pop_back()
				loop_closed = _path_has_repeat()
			elif not loop_closed and _adjacent(cell, last):
				var d: MourkDot = _dot_at(cell)
				var first: MourkDot = _dot_at(path[0])
				if d != null and not d.veiled and first != null and d.color_idx == first.color_idx:
					var closes := path.has(cell)
					path.append(cell)
					d.bump()
					if closes:
						loop_closed = true
						_pulse_hue(d.color_idx)
	line_layer.queue_redraw()


func _end_drag() -> void:
	if not dragging:
		return
	dragging = false
	if path.size() < 2:
		path.clear()
		line_layer.queue_redraw()
		return
	var color: int = _dot_at(path[0]).color_idx
	var cells := {}
	if loop_closed:
		for c in COLS:
			for r in ROWS:
				var d: MourkDot = grid[c][r]
				if d != null and not d.veiled and d.color_idx == color:
					cells[Vector2i(c, r)] = true
	else:
		for cell in path:
			cells[cell] = true
	path.clear()
	loop_closed = false
	line_layer.queue_redraw()
	_resolve(cells.keys(), color)


# ── Resolution ────────────────────────────────────────────────────────────────

func _resolve(cells: Array, color: int) -> void:
	busy = true
	moves_left -= 1

	# Lift veils next to gathered motes.
	for cell in cells:
		for n in _neighbours(cell):
			var nd: MourkDot = _dot_at(n)
			if nd != null and nd.veiled:
				nd.unveil()
				veils_left -= 1

	# Count toward the hue goal and clear the motes.
	if goals.has(color):
		goals[color] = maxi(0, goals[color] - cells.size())
	for cell in cells:
		var d: MourkDot = _dot_at(cell)
		grid[cell.x][cell.y] = null
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "scale", Vector2(1.6, 1.6), 0.16).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(d, "modulate", Color(1, 1, 1, 0), 0.16)
		tw.chain().tween_callback(d.queue_free)

	_refresh_hud()
	await get_tree().create_timer(0.18).timeout
	await _collapse_and_refill()

	if _goals_met():
		_finish(true)
	elif moves_left <= 0:
		_finish(false)
	else:
		_ensure_move_exists()
		busy = false


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
			for n in [Vector2i(c + 1, r), Vector2i(c, r + 1)]:
				var nd: MourkDot = _dot_at(n)
				if nd != null and not nd.veiled and nd.color_idx == d.color_idx:
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
		var chip := GoalChip.new(G.DOT_COLORS[k], false)
		chips.add_child(chip)
		goal_chips[k] = chip
	if level_def.veils > 0:
		var vchip := GoalChip.new(G.VEIL_COLOR, true)
		chips.add_child(vchip)
		goal_chips["veils"] = vchip

	var hint := UIH.make_label("Close a loop to gather every mote of its hue.", 20, Color(0.42, 0.46, 0.58))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position.y = -70
	hud.add_child(hint)


func _refresh_hud() -> void:
	moves_label.text = str(maxi(moves_left, 0))
	for k in goal_chips:
		if k is String:
			goal_chips[k].set_remaining(maxi(veils_left, 0))
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
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _neighbours(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x + 1, cell.y), Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1), Vector2i(cell.x, cell.y - 1),
	]


func _path_has_repeat() -> bool:
	var seen := {}
	for cell in path:
		if seen.has(cell):
			return true
		seen[cell] = true
	return false


func _pulse_hue(color: int) -> void:
	for c in COLS:
		for r in ROWS:
			var d: MourkDot = grid[c][r]
			if d != null and not d.veiled and d.color_idx == color:
				d.bump()


# ── Inner classes ─────────────────────────────────────────────────────────────

class LineLayer extends Node2D:
	var game

	func _init(p_game) -> void:
		game = p_game

	func _draw() -> void:
		if game.path.is_empty():
			return
		var first = game._dot_at(game.path[0])
		if first == null:
			return
		var col: Color = G.DOT_COLORS[first.color_idx]
		col = col.lightened(0.2)
		col.a = 0.9 if game.loop_closed else 0.7
		var pts := PackedVector2Array()
		for cell in game.path:
			pts.append(game._cell_pos(cell))
		if game.dragging:
			pts.append(game.drag_pos)
		if pts.size() >= 2:
			draw_polyline(pts, col, 10.0, true)
		for p in pts:
			draw_circle(p, 6.0, col)


class GoalChip extends Control:
	var chip_color: Color
	var is_veil := false
	var remaining := 0

	func _init(p_color: Color, p_veil: bool) -> void:
		chip_color = p_color
		is_veil = p_veil
		custom_minimum_size = Vector2(76, 92)

	func set_remaining(n: int) -> void:
		remaining = n
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, 30.0)
		if is_veil:
			draw_circle(center, 22.0, Color(0.14, 0.16, 0.22))
			draw_arc(center, 22.0, 0.0, TAU, 32, chip_color, 3.0)
		else:
			var glow := chip_color
			glow.a = 0.2
			draw_circle(center, 30.0, glow)
			draw_circle(center, 22.0, chip_color)
		var done := remaining <= 0
		var txt := "OK" if done else str(remaining)
		var txt_col := Color(0.36, 0.92, 0.48) if done else Color(0.92, 0.93, 0.97)
		draw_string(ThemeDB.fallback_font, Vector2(0, 84), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, txt_col)
