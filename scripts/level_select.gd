extends Control

# ── The descent ───────────────────────────────────────────────────────────────
#
# Threads are stops on a mine line winding down through the cave. You read it
# bottom-to-top: thread 1 is the mouth near the surface, thread 20 is the
# deepest cut. Cleared stops burn gold, the next one pulses, the rest sit dark
# behind the veil.

const STOP_GAP := 190.0          # vertical distance between stops
const TOP_PAD := 180.0
const BOTTOM_PAD := 210.0
const SWAY := 150.0              # how far the line wanders off centre

var _stops: Array[Vector2] = []
var _scroll: ScrollContainer
var _canvas: CaveCanvas


func _ready() -> void:
	var vp := get_viewport_rect().size
	var count := G.level_count()
	var height := TOP_PAD + BOTTOM_PAD + STOP_GAP * float(count - 1)

	var bg := ColorRect.new()
	bg.color = G.BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Deepest thread at the top of the scroll, thread 1 at the bottom.
	for i in count:
		var y := height - BOTTOM_PAD - STOP_GAP * float(i)
		var x := vp.x * 0.5 + sin(float(i) * 0.9) * SWAY
		_stops.append(Vector2(x, y))

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_canvas = CaveCanvas.new(self)
	_canvas.custom_minimum_size = Vector2(vp.x, height)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_canvas)

	for i in count:
		var stop := StopButton.new(i, _state_of(i))
		stop.position = _stops[i] - Vector2(StopButton.R, StopButton.R)
		if _state_of(i) != 0:
			var idx := i
			stop.pressed.connect(func() -> void:
				G.current_level = idx
				get_tree().change_scene_to_file("res://scenes/Game.tscn"))
		_canvas.add_child(stop)

	# Title and back sit above the scroll so they stay put. Scrims keep them
	# legible as stops scroll underneath.
	var top_scrim := ColorRect.new()
	top_scrim.color = Color(G.BG_COLOR.r, G.BG_COLOR.g, G.BG_COLOR.b, 0.88)
	top_scrim.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_scrim.custom_minimum_size = Vector2(0, 88)
	top_scrim.size.y = 88
	top_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_scrim)

	var bot_scrim := ColorRect.new()
	bot_scrim.color = Color(G.BG_COLOR.r, G.BG_COLOR.g, G.BG_COLOR.b, 0.88)
	bot_scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_scrim.offset_top = -110
	bot_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot_scrim)

	var top := UIH.make_label("THE  DESCENT", 40, G.GOLD)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.position.y = 26
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var back := UIH.make_button("BACK", 26, Color(0.6, 0.64, 0.76))
	back.position = Vector2(20, vp.y - 92)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	add_child(back)

	# Open on the deepest stop reached, not at the surface.
	await get_tree().process_frame
	var focus: int = clampi(G.unlocked - 1, 0, count - 1)
	_scroll.scroll_vertical = int(maxi(0, int(_stops[focus].y - vp.y * 0.62)))


# 0 locked, 1 open, 2 cleared
func _state_of(i: int) -> int:
	if i + 1 > G.unlocked:
		return 0
	return 2 if i + 1 < G.unlocked else 1


# ── Cave drawing ──────────────────────────────────────────────────────────────

class CaveCanvas extends Control:
	var owner_ref
	var _rng := RandomNumberGenerator.new()

	func _init(p_owner) -> void:
		owner_ref = p_owner
		_rng.seed = 20260802     # fixed, so the cave is the same cave every time

	func _draw() -> void:
		var stops: Array[Vector2] = owner_ref._stops
		if stops.is_empty():
			return
		var w := size.x
		var h := size.y

		# Rock walls: jagged silhouettes crowding in from both sides.
		_rng.seed = 20260802
		var step := 70.0
		var left := PackedVector2Array([Vector2(0, 0)])
		var right := PackedVector2Array([Vector2(w, 0)])
		var y := 0.0
		while y < h:
			var t := y / h
			var squeeze := 90.0 + 60.0 * sin(t * 9.0)
			left.append(Vector2(squeeze + _rng.randf_range(-38.0, 38.0), y))
			right.append(Vector2(w - squeeze + _rng.randf_range(-38.0, 38.0), y))
			y += step
		left.append(Vector2(0, h))
		right.append(Vector2(w, h))
		var rock := Color(0.055, 0.075, 0.115)
		draw_colored_polygon(left, rock)
		draw_colored_polygon(right, rock)
		var rim := Color(0.16, 0.20, 0.29, 0.55)
		draw_polyline(left.slice(1, left.size() - 1), rim, 2.0, true)
		draw_polyline(right.slice(1, right.size() - 1), rim, 2.0, true)

		# Mourk seams glinting in the walls.
		for i in 46:
			var sy := _rng.randf_range(0.0, h)
			var on_left := _rng.randf() < 0.5
			var sx := _rng.randf_range(18.0, 92.0)
			if not on_left:
				sx = w - sx
			var col: Color = G.DOT_COLORS[_rng.randi() % G.DOT_COLORS.size()]
			col.a = 0.20
			var rr := _rng.randf_range(3.0, 8.0)
			draw_circle(Vector2(sx, sy), rr * 2.4, Color(col.r, col.g, col.b, 0.06))
			draw_circle(Vector2(sx, sy), rr, col)

		# The mine line itself, threaded stop to stop.
		var line := PackedVector2Array()
		for i in stops.size():
			if i == 0:
				line.append(stops[i])
				continue
			# a slack curve between stops rather than a straight rail
			var a: Vector2 = stops[i - 1]
			var b: Vector2 = stops[i]
			for k in range(1, 9):
				var tt := float(k) / 8.0
				var p := a.lerp(b, tt)
				p.x += sin(tt * PI) * ((b.x - a.x) * 0.16)
				p.y += sin(tt * PI) * 16.0
				line.append(p)
		draw_polyline(line, Color(0.20, 0.24, 0.33, 0.85), 7.0, true)
		draw_polyline(line, Color(0.36, 0.41, 0.53, 0.6), 2.5, true)

		# The lit stretch: everything already cleared glows gold.
		var lit := clampi(G.unlocked - 1, 0, stops.size() - 1)
		if lit > 0:
			var glow := PackedVector2Array()
			for i in range(0, lit * 8 + 1):
				if i < line.size():
					glow.append(line[i])
			if glow.size() >= 2:
				draw_polyline(glow, Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.22), 11.0, true)
				draw_polyline(glow, Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.75), 3.0, true)

		# Depth markers down the side.
		for i in stops.size():
			if i % 5 != 4:
				continue
			var label := "-%d00 m" % (i + 1)
			draw_string(ThemeDB.fallback_font, Vector2(w - 150.0, stops[i].y - 54.0),
				label, HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 20,
				Color(0.34, 0.38, 0.50))


class StopButton extends Button:
	const R := 42.0

	var idx := 0
	var state := 0      # 0 locked, 1 open, 2 cleared
	var _t := 0.0

	func _init(p_idx: int, p_state: int) -> void:
		idx = p_idx
		state = p_state
		custom_minimum_size = Vector2(R * 2.0, R * 2.0)
		size = custom_minimum_size
		flat = true
		focus_mode = Control.FOCUS_NONE
		disabled = state == 0
		# The button is only a hit box; everything visible is drawn below.
		add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		set_process(state == 1)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(R, R)
		var gold: Color = G.GOLD
		match state:
			2:
				draw_circle(c, R * 1.5, Color(gold.r, gold.g, gold.b, 0.10))
				draw_circle(c, R * 0.86, Color(0.09, 0.11, 0.16))
				draw_arc(c, R * 0.86, 0.0, TAU, 40, gold, 3.0)
			1:
				var pulse := 0.5 + 0.5 * sin(_t * 2.6)
				draw_circle(c, R * (1.5 + 0.22 * pulse),
					Color(gold.r, gold.g, gold.b, 0.10 + 0.10 * pulse))
				draw_circle(c, R * 0.86, Color(0.12, 0.14, 0.20))
				draw_arc(c, R * 0.86, 0.0, TAU, 40,
					Color(1, 1, 1, 0.65 + 0.35 * pulse), 3.5)
			_:
				draw_circle(c, R * 0.80, Color(0.07, 0.08, 0.12))
				draw_arc(c, R * 0.80, 0.0, TAU, 36, Color(0.22, 0.25, 0.33), 2.0)

		var txt := str(idx + 1)
		var col := Color(0.30, 0.34, 0.44)
		if state == 2:
			col = gold
		elif state == 1:
			col = Color(1, 1, 1)
		draw_string(ThemeDB.fallback_font, Vector2(0, R + 11.0), txt,
			HORIZONTAL_ALIGNMENT_CENTER, R * 2.0, 30, col)
