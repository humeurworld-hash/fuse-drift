extends CanvasLayer
class_name TutorialCard

signal tutorial_done

const AUTO_DISMISS := 10.0   # auto-close after 10 s if player doesn't tap

var _timer: float = AUTO_DISMISS
var _panel: Panel = null

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_dismiss()

# ── Card layout ────────────────────────────────────────────────────────────────

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Full-screen dark overlay (slightly stronger so the panel pops)
	var ov := ColorRect.new()
	ov.color = Color(0.0, 0.0, 0.0, 0.72)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ov)

	# Card dimensions
	var cw := minf(vp.x * 0.90, 560.0)
	const TITLE_H  : float = 54.0
	const SEP_H    : float = 2.0
	const TIP_H    : float = 58.0
	const N_TIPS   : int   = 5
	const BTN_H    : float = 58.0
	const PAD      : float = 22.0
	var ch := TITLE_H + SEP_H + (N_TIPS * TIP_H) + PAD + BTN_H + PAD

	_panel = Panel.new()
	_panel.size     = Vector2(cw, ch)
	_panel.position = Vector2((vp.x - cw) * 0.5, vp.y)   # starts below screen
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.06, 0.10, 0.20, 0.98)
	sty.border_color = Color(0.22, 0.88, 0.85, 1.0)
	sty.set_border_width_all(3)
	sty.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color",        Color(0.22, 0.92, 0.86, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(cw, TITLE_H)
	title.position = Vector2(0.0, 12.0)
	_panel.add_child(title)

	# ── Separator ─────────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.color    = Color(0.22, 0.88, 0.85, 0.35)
	sep.size     = Vector2(cw - 32.0, 1.0)
	sep.position = Vector2(16.0, TITLE_H)
	_panel.add_child(sep)

	# ── Tips — keyword + description on each row ──────────────────────────────
	const TIPS : Array = [
		["DRAG",        "  — slide anywhere to move Fuse"],
		["DODGE",       "  — avoid rocks, drones & clocks"],
		["COLLECT",     "  — grab Mourk shards, build streak"],
		["GHOST DASH",  "  — bottom-left → 2.5 s invincible"],
		["SHARD PULSE", "  — bottom-right → magnetic pull"],
	]

	var row_y := TITLE_H + SEP_H + 8.0
	for tip in TIPS:
		# Teal keyword label
		var kw := Label.new()
		kw.text = tip[0]
		kw.add_theme_font_size_override("font_size", 20)
		kw.add_theme_color_override("font_color", Color(0.22, 0.92, 0.86, 1.0))
		kw.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		kw.add_theme_constant_override("shadow_offset_y", 1)
		kw.size     = Vector2(cw * 0.42, TIP_H)
		kw.position = Vector2(14.0, row_y)
		kw.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_panel.add_child(kw)

		# White description label
		var desc := Label.new()
		desc.text = tip[1]
		desc.add_theme_font_size_override("font_size", 19)
		desc.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 1.0))
		desc.size          = Vector2(cw * 0.58 - 14.0, TIP_H)
		desc.position      = Vector2(cw * 0.42, row_y)
		desc.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel.add_child(desc)

		row_y += TIP_H

	# ── "LET'S GO!" button ────────────────────────────────────────────────────
	var btn := Button.new()
	btn.text = "LET'S GO!"
	btn.custom_minimum_size = Vector2(cw - 32.0, BTN_H)
	btn.position = Vector2(16.0, row_y + PAD * 0.5)
	btn.add_theme_font_size_override("font_size", 28)

	var bs := StyleBoxFlat.new()
	bs.bg_color     = Color(0.10, 0.38, 0.65, 1.0)
	bs.border_color = Color(0.22, 0.82, 1.00, 1.0)
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", bs)

	var bsh := bs.duplicate() as StyleBoxFlat
	bsh.bg_color = Color(0.16, 0.54, 0.86, 1.0)
	btn.add_theme_stylebox_override("hover",   bsh)
	btn.add_theme_stylebox_override("pressed", bsh)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	btn.pressed.connect(_dismiss)
	_panel.add_child(btn)

	# ── Slide in from below ───────────────────────────────────────────────────
	var target_y := (vp.y - ch) * 0.5
	var t := _panel.create_tween()
	t.tween_property(_panel, "position:y", target_y, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Dismiss ────────────────────────────────────────────────────────────────────

func _dismiss() -> void:
	if not is_instance_valid(_panel):
		tutorial_done.emit()
		queue_free()
		return
	set_process(false)
	var vp := get_viewport().get_visible_rect().size
	var t := _panel.create_tween()
	t.tween_property(_panel, "position:y", vp.y + 20.0, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		tutorial_done.emit()
		queue_free()
	)
