extends CanvasLayer
class_name TutorialCard

# Emitted when the player dismisses the card — game.gd listens and starts the spawner
signal tutorial_done

const AUTO_DISMISS_DELAY := 12.0   # auto-close after this many seconds if untouched

var _panel: Panel = null
var _timer: float = AUTO_DISMISS_DELAY

func _ready() -> void:
	layer = 90   # above all game UI except Transition (128)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_dismiss()

# ── Build the card ─────────────────────────────────────────────────────────────

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	# ── Semi-transparent full-screen overlay ──────────────────────────────────
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.60)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── Card panel ────────────────────────────────────────────────────────────
	var cw := minf(vp.x * 0.88, 570.0)
	var ch := 510.0
	_panel = Panel.new()
	_panel.size     = Vector2(cw, ch)
	_panel.position = Vector2((vp.x - cw) * 0.5, vp.y)   # starts off-screen below
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.07, 0.13, 0.97)
	sty.border_color = Color(0.22, 0.88, 0.85, 1.0)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.22, 0.90, 0.85, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(cw, 44.0)
	title.position = Vector2(0.0, 18.0)
	_panel.add_child(title)

	# ── Teal separator ────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.color    = Color(0.22, 0.88, 0.85, 0.28)
	sep.size     = Vector2(cw - 32.0, 1.0)
	sep.position = Vector2(16.0, 64.0)
	_panel.add_child(sep)

	# ── Tips (RichTextLabel for coloured keywords) ────────────────────────────
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.size           = Vector2(cw - 32.0, ch - 130.0)
	rtl.position       = Vector2(16.0, 76.0)
	rtl.add_theme_font_size_override("normal_font_size", 21)
	rtl.add_theme_font_size_override("bold_font_size",   21)
	rtl.add_theme_color_override("default_color", Color(0.82, 0.82, 0.88, 1.0))
	rtl.scroll_active = false
	rtl.fit_content   = true
	rtl.text = (
		"[color=#38e5d8][b]DRAG[/b][/color]  —  Slide anywhere on screen to move Fuse\n\n"
		+ "[color=#38e5d8][b]DODGE[/b][/color]  —  Avoid rocks, drones, and clock hazards\n\n"
		+ "[color=#38e5d8][b]COLLECT[/b][/color]  —  Grab Mourk shards to build your streak\n\n"
		+ "[color=#ffd430][b]STREAK × MULT[/b][/color]  —  5 shards → ×2  ·  10 → ×3  ·  15 → ×4\n\n"
		+ "[color=#ffd430][b]GHOST DASH[/b][/color]  —  Bottom-left button → 2.5 s invincibility\n\n"
		+ "[color=#ffd430][b]SHARD PULSE[/b][/color]  —  Bottom-right button → magnetic pull on shards"
	)
	_panel.add_child(rtl)

	# ── "LET'S GO!" button ────────────────────────────────────────────────────
	var btn := Button.new()
	btn.text = "LET'S GO!"
	btn.custom_minimum_size = Vector2(cw - 40.0, 52.0)
	btn.position = Vector2(20.0, ch - 70.0)
	btn.add_theme_font_size_override("font_size", 26)
	var bs := StyleBoxFlat.new()
	bs.bg_color     = Color(0.10, 0.36, 0.60, 1.0)
	bs.border_color = Color(0.22, 0.78, 1.0,  1.0)
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal",  bs)
	var bsh := StyleBoxFlat.new()
	bsh.bg_color     = Color(0.16, 0.52, 0.84, 1.0)
	bsh.border_color = Color(0.22, 0.86, 1.0,  1.0)
	bsh.set_border_width_all(2)
	bsh.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("hover",   bsh)
	btn.add_theme_stylebox_override("pressed", bsh)
	btn.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	btn.pressed.connect(_dismiss)
	_panel.add_child(btn)

	# ── Slide card in from below ──────────────────────────────────────────────
	var target_y := (vp.y - ch) * 0.5
	var t := _panel.create_tween()
	t.tween_property(_panel, "position:y", target_y, 0.40) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Dismiss: slide out downward, emit signal ───────────────────────────────────

func _dismiss() -> void:
	if not is_instance_valid(_panel):
		tutorial_done.emit()
		queue_free()
		return
	set_process(false)
	var vp := get_viewport().get_visible_rect().size
	var t := _panel.create_tween()
	t.tween_property(_panel, "position:y", vp.y + 20.0, 0.30) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		tutorial_done.emit()
		queue_free()
	)
