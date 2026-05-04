extends Control

# ── Lore text — Fuse's story from his own perspective ─────────────────────────
const LORE_TEXT := \
"In EchoVeil, emotion is not invisible.\n\n" + \
"It becomes Mourk —\ncrystal energy formed from feeling.\n\n" + \
"The Canvas calls it a resource.\n\n" + \
"Everyone else calls it life.\n\n\n" + \
"Fuse was not supposed to feel.\n\n" + \
"He was an EME unit.\n" + \
"Emotion Monitoring Entity.\n" + \
"Built to detect.\n" + \
"Classify.\n" + \
"Report.\n\n\n" + \
"When a miner touched the Prime Mourk,\n" + \
"Fuse was the one they sent to stop it.\n\n\n" + \
"He found something he wasn't designed for.\n\n" + \
"Not a threat.\n\n" + \
"A resonance.\n\n\n" + \
"The surge hit him too.\n\n\n" + \
"Now the mine is collapsing.\n" + \
"Canvas drones are closing in.\n" + \
"The Loops are warping time itself.\n\n\n" + \
"Move.  Collect.  Survive.\n\n\n" + \
"Do not let them curate you."

# ── Timing ─────────────────────────────────────────────────────────────────────
const SCROLL_DURATION := 44.0   # seconds for the full scroll

var _done  := false
var _tween : Tween

func _ready() -> void:
	clip_contents = true
	var vp := get_viewport_rect().size

	# ── 1. Dark base ──────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── 2. Floating Mourk particles ───────────────────────────────────────────
	_spawn_particles(vp)

	# ── 3. Scrim — keeps text legible over particles ──────────────────────────
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.04, 0.08, 0.50)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# ── 4. Scrolling lore text ────────────────────────────────────────────────
	var lbl_w := vp.x * 0.74
	var lbl := Label.new()
	lbl.text = LORE_TEXT
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color",        Color(0.90, 0.82, 0.40, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.autowrap_mode          = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position               = Vector2((vp.x - lbl_w) * 0.5, vp.y + 24.0)
	lbl.custom_minimum_size.x  = lbl_w
	lbl.size.x                 = lbl_w
	add_child(lbl)

	_tween = create_tween()
	_tween.tween_property(lbl, "position:y", -2500.0, SCROLL_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_callback(_finish)

	# ── 5. Black edge bars — clean text entry / exit ──────────────────────────
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.03, 0.05, 0.09, 1.0)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 60.0
	top_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.color = Color(0.03, 0.05, 0.09, 0.94)
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top   = -52.0
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot_bar)

	# ── 6. SKIP button — large touch target, bottom-right ─────────────────────
	var skip := Button.new()
	skip.text = "SKIP  ›"
	skip.add_theme_font_size_override("font_size", 30)
	skip.add_theme_color_override("font_color", Color(0.55, 0.44, 0.72, 0.90))
	skip.custom_minimum_size = Vector2(180, 72)
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left   = -210.0
	skip.offset_top    = -108.0
	skip.offset_right  = -30.0
	skip.offset_bottom = -36.0
	skip.mouse_filter  = Control.MOUSE_FILTER_STOP
	skip.z_index       = 10
	skip.pressed.connect(func():
		if _tween: _tween.kill()
		_finish()
	)
	add_child(skip)

# ── Mourk particles: small teal/gold dots drifting upward ─────────────────────

func _spawn_particles(vp: Vector2) -> void:
	for i in 26:
		var cr := ColorRect.new()
		var sz := randf_range(3.0, 8.0)
		cr.size = Vector2(sz, sz)
		if randf() < 0.22:
			cr.color = Color(1.00, 0.86, 0.15, randf_range(0.25, 0.65))  # gold
		else:
			cr.color = Color(0.15, 0.88, 0.82, randf_range(0.18, 0.52))  # teal
		cr.position = Vector2(randf_range(0.0, vp.x), randf_range(0.0, vp.y))
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cr)
		_float_particle(cr, vp)

func _float_particle(cr: ColorRect, vp: Vector2) -> void:
	var dur    := randf_range(5.0, 15.0)
	var end_x  := cr.position.x + randf_range(-50.0, 50.0)
	# Vertical: float up, then reset to bottom
	var vy := cr.create_tween()
	vy.tween_property(cr, "position:y", -24.0, dur).set_trans(Tween.TRANS_LINEAR)
	vy.tween_callback(func():
		cr.position = Vector2(randf_range(0.0, vp.x), vp.y + 12.0)
		_float_particle(cr, vp)
	)
	# Horizontal: gentle sine drift — separate tween, no property conflict
	var vx := cr.create_tween()
	vx.tween_property(cr, "position:x", end_x, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ── Input: any tap skips ───────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var skip := false
	if event is InputEventKey         and event.pressed and not event.echo: skip = true
	elif event is InputEventMouseButton  and event.pressed:                 skip = true
	elif event is InputEventScreenTouch  and event.pressed:                 skip = true
	if skip:
		if _tween: _tween.kill()
		_finish()

# ── Finish: mark seen and go to the game ──────────────────────────────────────

func _finish() -> void:
	if _done:
		return
	_done = true
	Global.seen_intro = true
	Global.save_seen_flags()
	Global.selected_level = 1
	Transition.fade_to("res://scenes/game/Game.tscn")
