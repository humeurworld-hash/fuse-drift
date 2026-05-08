extends Node2D

# ── Image-based Level Select ──────────────────────────────────────────────────
# Background artwork fills the 720×1280 viewport (image is 941×1672 = same 9:16
# aspect). Transparent buttons are overlaid over each level row and BACK.
# Locked levels get a dark overlay so they look dimmed.

const IMG_PATH := "res://scenes/levels/level_select_screen.png"

const LEVEL_NAMES := {
	1: "The Cave",
	2: "The Verge",
	3: "The Loops",
}

# Keep @onready refs so the scene doesn't error — we hide them all in _ready().
@onready var back_button:           Button        = $UI/BackButton
@onready var level1_button:         TextureButton = $UI/Level1Button
@onready var level1_best:           Label         = $UI/Level1Best
@onready var level2_button:         TextureButton = $UI/Level2Button
@onready var level2_best:           Label         = $UI/Level2Best
@onready var level2_lock_overlay:   ColorRect     = $UI/Level2LockOverlay
@onready var level2_lock_label:     Label         = $UI/Level2LockLabel
@onready var level3_button:         TextureButton = $UI/Level3Button
@onready var level3_best:           Label         = $UI/Level3Best
@onready var level3_lock_overlay:   ColorRect     = $UI/Level3LockOverlay
@onready var level3_lock_label:     Label         = $UI/Level3LockLabel

var _pending_level: int   = 0
var _picker_panel:  Panel = null
var _darkener: ColorRect  = null

func _ready() -> void:
	_hide_old_nodes()
	_build_image_screen()

# ── Hide all scene-built nodes ────────────────────────────────────────────────

func _hide_old_nodes() -> void:
	for child in $UI.get_children():
		child.visible = false

# ── Build image-based screen ──────────────────────────────────────────────────

func _build_image_screen() -> void:
	var vp := get_viewport_rect().size
	var W   := vp.x
	var H   := vp.y

	# Background image
	var _bg_raw := Image.load_from_file(ProjectSettings.globalize_path(IMG_PATH))
	var _bg_tex: Texture2D = ImageTexture.create_from_image(_bg_raw) if _bg_raw else null
	if _bg_tex:
		var bg := TextureRect.new()
		bg.texture      = _bg_tex
		bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.size         = vp
		bg.position     = Vector2.ZERO
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$UI.add_child(bg)

	# ── Level button rows (measured as fractions of 720×1280) ─────────────────
	# THE CAVE:  y 27–44 %
	# THE VERGE: y 47–63 %
	# THE LOOPS: y 66–82 %
	# BACK:      y 86–95 %,  x 22–78 %
	var level_rows := [
		[1, 0.27, 0.17],   # [level, y_frac, h_frac]
		[2, 0.47, 0.16],
		[3, 0.66, 0.16],
	]
	var lx := W * 0.08
	var lw := W * 0.84

	for row in level_rows:
		var level: int  = row[0]
		var y_frac: float = row[1]
		var h_frac: float = row[2]
		var ry := H * y_frac
		var rh := H * h_frac

		# Lock overlay (dark tint) if level is not unlocked
		if level > 1 and not Global.is_unlocked(level):
			var lock_ov := ColorRect.new()
			lock_ov.color        = Color(0.0, 0.0, 0.0, 0.68)
			lock_ov.size         = Vector2(lw, rh)
			lock_ov.position     = Vector2(lx, ry)
			lock_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$UI.add_child(lock_ov)

			var lock_lbl := Label.new()
			lock_lbl.text = "🔒  LOCKED"
			lock_lbl.add_theme_font_size_override("font_size", 28)
			lock_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lock_lbl.size     = Vector2(lw, rh)
			lock_lbl.position = Vector2(lx, ry)
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$UI.add_child(lock_lbl)
			continue   # no tap button for locked levels

		# Best score label in top-right of the row
		var best := Global.get_best(level)
		if best > 0:
			var best_lbl := Label.new()
			best_lbl.text = "Best: %d" % best
			best_lbl.add_theme_font_size_override("font_size", 18)
			best_lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.95, 1.0))
			best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			best_lbl.size     = Vector2(lw - 16.0, 28.0)
			best_lbl.position = Vector2(lx + 8.0, ry + 6.0)
			best_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$UI.add_child(best_lbl)

		# Transparent tap button over the row
		var btn := Button.new()
		btn.flat = true
		var empty := StyleBoxEmpty.new()
		for state in ["normal","hover","pressed","focus","disabled"]:
			btn.add_theme_stylebox_override(state, empty)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.size     = Vector2(lw, rh)
		btn.position = Vector2(lx, ry)
		var lvl_capture := level
		btn.pressed.connect(func(): _show_difficulty_picker(lvl_capture))
		$UI.add_child(btn)

	# BACK button
	var back_btn := Button.new()
	back_btn.flat = true
	var empty2 := StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","focus","disabled"]:
		back_btn.add_theme_stylebox_override(state, empty2)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.size     = Vector2(W * 0.56, H * 0.075)
	back_btn.position = Vector2(W * 0.22, H * 0.865)
	back_btn.pressed.connect(_on_back)
	$UI.add_child(back_btn)

# ── Difficulty picker (slides up from bottom) ─────────────────────────────────

func _show_difficulty_picker(level: int) -> void:
	if _picker_panel != null:
		return
	_pending_level = level

	var vp := get_viewport_rect().size
	const PH := 320.0

	_darkener = ColorRect.new()
	_darkener.color = Color(0.0, 0.0, 0.0, 0.65)
	_darkener.set_anchors_preset(Control.PRESET_FULL_RECT)
	_darkener.mouse_filter = Control.MOUSE_FILTER_STOP
	_darkener.modulate = Color(1, 1, 1, 0)
	$UI.add_child(_darkener)
	_darkener.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_hide_difficulty_picker()
	)

	_picker_panel = Panel.new()
	_picker_panel.size     = Vector2(vp.x, PH)
	_picker_panel.position = Vector2(0.0, vp.y)
	var sty := StyleBoxFlat.new()
	sty.bg_color      = Color(0.04, 0.07, 0.14, 0.98)
	sty.border_color  = Color(0.22, 0.82, 0.88, 1.0)
	sty.border_width_top = 2
	_picker_panel.add_theme_stylebox_override("panel", sty)
	$UI.add_child(_picker_panel)

	var header := Label.new()
	header.text = "LEVEL %d  —  %s" % [level, LEVEL_NAMES.get(level, "")]
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.60, 0.90, 0.92, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size     = Vector2(vp.x, 38.0)
	header.position = Vector2(0.0, 18.0)
	_picker_panel.add_child(header)

	var sub := Label.new()
	sub.text = "CHOOSE DIFFICULTY"
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 1.0))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	sub.add_theme_constant_override("shadow_offset_y", 2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size     = Vector2(vp.x, 42.0)
	sub.position = Vector2(0.0, 56.0)
	_picker_panel.add_child(sub)

	const DIFF_COLORS := [
		Color(0.12, 0.48, 0.22, 1.0),
		Color(0.12, 0.28, 0.58, 1.0),
		Color(0.52, 0.12, 0.12, 1.0),
	]
	const DIFF_BORDER := [
		Color(0.22, 0.92, 0.44, 1.0),
		Color(0.22, 0.70, 1.00, 1.0),
		Color(1.00, 0.28, 0.28, 1.0),
	]
	const DIFF_LABELS := ["EASY", "MEDIUM", "HARD"]
	const DIFF_SUBS   := ["0.65×  speed", "1.0×  speed", "1.5×  speed\n+35% score"]

	var btn_w := (vp.x - 48.0) / 3.0
	const BTN_H := 120.0

	for i in 3:
		var bs := StyleBoxFlat.new()
		bs.bg_color     = DIFF_COLORS[i]
		bs.border_color = DIFF_BORDER[i]
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(10)
		var bsh := bs.duplicate() as StyleBoxFlat
		bsh.bg_color = DIFF_COLORS[i].lightened(0.15)

		var btn := Button.new()
		btn.flat = false
		btn.add_theme_stylebox_override("normal",  bs)
		btn.add_theme_stylebox_override("hover",   bsh)
		btn.add_theme_stylebox_override("pressed", bsh)
		btn.size     = Vector2(btn_w, BTN_H)
		btn.position = Vector2(16.0 + i * (btn_w + 8.0), 112.0)
		_picker_panel.add_child(btn)

		var lbl := Label.new()
		lbl.text = DIFF_LABELS[i]
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size     = Vector2(btn_w, 44.0)
		lbl.position = Vector2(0.0, 14.0)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl)

		var sub_lbl := Label.new()
		sub_lbl.text = DIFF_SUBS[i]
		sub_lbl.add_theme_font_size_override("font_size", 14)
		sub_lbl.add_theme_color_override("font_color", DIFF_BORDER[i])
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.size     = Vector2(btn_w, 50.0)
		sub_lbl.position = Vector2(0.0, 58.0)
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(sub_lbl)

		var diff_idx := i
		btn.pressed.connect(func(): _on_difficulty_chosen(diff_idx))

	var t := _picker_panel.create_tween()
	t.set_parallel(true)
	t.tween_property(_picker_panel, "position:y", vp.y - PH, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_darkener, "modulate", Color(1, 1, 1, 1), 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _hide_difficulty_picker() -> void:
	if _picker_panel == null:
		return
	var vp := get_viewport_rect().size
	var t := _picker_panel.create_tween()
	t.set_parallel(true)
	t.tween_property(_picker_panel, "position:y", vp.y, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_darkener, "modulate", Color(1, 1, 1, 0), 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		if is_instance_valid(_picker_panel): _picker_panel.queue_free()
		if is_instance_valid(_darkener):     _darkener.queue_free()
		_picker_panel = null
		_darkener     = null
	)

func _on_difficulty_chosen(diff: int) -> void:
	Global.difficulty    = diff
	Global.carry_score   = 0.0
	Global.selected_level = _pending_level
	Transition.fade_to("res://scenes/game/Game.tscn")

# ── Navigation ────────────────────────────────────────────────────────────────

func _on_back() -> void:
	Transition.fade_to("res://scenes/menu/Menu.tscn")
