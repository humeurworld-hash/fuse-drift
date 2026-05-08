extends Node2D

const BG_PATHS := [
	"res://scenes/menu/Menu Background.PNG",
	"res://scenes/menu/Landing Page.PNG",
	"res://scenes/menu/menu_bg.PNG",
	"res://scenes/menu/menu_bg.png",
]

const FUSE_IDLE_PATHS := [
	"res://scenes/player/fuse/New Fuse/idle.png",
	"res://scenes/player/fuse/idle.png",
]

const LEVEL_NAMES := {
	1: "Level 1 — The Cave",
	2: "Level 2 — The Verge",
	3: "Level 3 — The Loops",
}

@onready var fallback_bg:        ColorRect    = $FallbackBG
@onready var background_art:     Sprite2D     = $BackgroundArt
@onready var best_score_label:   Label        = $UI/BestScoreLabel
@onready var continue_button:    TextureButton = $UI/ContinueButton
@onready var continue_level_label: Label      = $UI/ContinueLevelLabel
@onready var run_button:         TextureButton = $UI/RunButton
@onready var levels_button:      TextureButton = $UI/LevelsButton
@onready var settings_button:    TextureButton = $UI/SettingsButton
@onready var title_label:        Label        = $UI/TitleLabel
@onready var subtitle_label:     Label        = $UI/SubtitleLabel
@onready var ui_layer:           CanvasLayer  = $UI

var _continue_level: int = 1

# Settings panel (built in code)
var _settings_panel:   Panel   = null
var _music_slider:     HSlider = null
var _sfx_slider:       HSlider = null
var _vibration_label:  Label   = null
var _tutorial_label:   Label   = null

# Fuse idle sprite
var _fuse_sprite: Sprite2D = null
var _fuse_bob_tween: Tween = null

func _ready() -> void:
	_setup_background()
	_load_scores()
	_setup_continue()
	_setup_title()
	_spawn_fuse_sprite()
	_build_settings_panel()
	_clear_btn_bg(continue_button)
	_clear_btn_bg(run_button)
	_clear_btn_bg(levels_button)
	_clear_btn_bg(settings_button)
	continue_button.pressed.connect(_on_continue)
	run_button.pressed.connect(_on_run)
	levels_button.pressed.connect(_on_levels)
	settings_button.pressed.connect(_on_settings)

# ── Background ────────────────────────────────────────────────────────────────

func _clear_btn_bg(btn: TextureButton) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)

func _setup_background() -> void:
	var vp := get_viewport_rect().size
	fallback_bg.size = vp
	fallback_bg.visible = true
	background_art.visible = false
	for path in BG_PATHS:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex:
				background_art.texture = tex
				background_art.position = vp * 0.5
				var s := tex.get_size()
				background_art.scale = Vector2.ONE * maxf(vp.x / s.x, vp.y / s.y)
				background_art.visible = true
				fallback_bg.visible = false
				return

# ── Scores / continue ─────────────────────────────────────────────────────────

func _load_scores() -> void:
	var overall := Global.get_overall_best()
	best_score_label.text = "BEST: %s" % (str(overall) if overall > 0 else "—")

func _setup_continue() -> void:
	var highest_unlocked := 1
	for lvl in [3, 2]:
		if Global.is_unlocked(lvl):
			highest_unlocked = lvl
			break
	if highest_unlocked <= 1:
		continue_button.visible = false
		continue_level_label.visible = false
		return
	_continue_level = highest_unlocked
	continue_button.visible = true
	continue_level_label.visible = true
	continue_level_label.text = LEVEL_NAMES.get(highest_unlocked, "")

# ── Title card ────────────────────────────────────────────────────────────────

func _setup_title() -> void:
	# Title — slam in from above with teal glow
	title_label.visible = true
	title_label.modulate = Color(1, 1, 1, 0)
	title_label.position.y -= 40.0
	var tt := title_label.create_tween()
	tt.set_parallel(true)
	tt.tween_property(title_label, "modulate", Color(1, 1, 1, 1), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tt.tween_property(title_label, "position:y", title_label.position.y + 40.0, 0.40) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Subtitle — fade in after title
	subtitle_label.visible = true
	subtitle_label.modulate = Color(1, 1, 1, 0)
	var st := subtitle_label.create_tween()
	st.tween_interval(0.45)
	st.tween_property(subtitle_label, "modulate", Color(1, 1, 1, 1), 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Gentle pulse on title (loops forever)
	var pulse := title_label.create_tween().set_loops()
	pulse.tween_interval(2.8)
	pulse.tween_property(title_label, "modulate", Color(0.78, 1.0, 0.97, 1.0), 0.55) \
		.set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.55) \
		.set_trans(Tween.TRANS_SINE)

# ── Fuse idle sprite in background ───────────────────────────────────────────

func _spawn_fuse_sprite() -> void:
	var vp := get_viewport_rect().size
	for path in FUSE_IDLE_PATHS:
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex == null:
				continue
			_fuse_sprite = Sprite2D.new()
			_fuse_sprite.texture = tex
			_fuse_sprite.scale = Vector2.ONE * 0.46
			_fuse_sprite.position = Vector2(vp.x * 0.5, vp.y * 0.54)
			_fuse_sprite.modulate = Color(1, 1, 1, 0)
			add_child(_fuse_sprite)
			# Move behind the UI layer but in front of background
			move_child(_fuse_sprite, get_child_count() - 2)
			# Fade in
			var ft := _fuse_sprite.create_tween()
			ft.tween_property(_fuse_sprite, "modulate", Color(1, 1, 1, 0.82), 0.70) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			# Start bob loop after fade
			ft.tween_callback(_start_fuse_bob)
			return

func _start_fuse_bob() -> void:
	if _fuse_sprite == null or not is_instance_valid(_fuse_sprite):
		return
	_fuse_bob_tween = _fuse_sprite.create_tween().set_loops()
	_fuse_bob_tween.tween_property(_fuse_sprite, "position:y",
		_fuse_sprite.position.y - 18.0, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fuse_bob_tween.tween_property(_fuse_sprite, "position:y",
		_fuse_sprite.position.y + 18.0, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ── Settings panel — image-based ─────────────────────────────────────────────

func _build_settings_panel() -> void:
	var vp := get_viewport_rect().size

	_settings_panel = Panel.new()
	_settings_panel.size     = vp
	_settings_panel.position = Vector2.ZERO
	_settings_panel.modulate = Color(1, 1, 1, 0)
	_settings_panel.visible  = false
	_settings_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# ── Background image ────────────────────────────────────────────────────────
	const IMG := "res://scenes/menu/settings_screen.png"
	if ResourceLoader.exists(IMG):
		var tex: Texture2D = load(IMG)
		if tex:
			var bg := TextureRect.new()
			bg.texture      = tex
			bg.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			bg.size         = vp
			bg.position     = Vector2.ZERO
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_settings_panel.add_child(bg)

	# ── Positions as fractions of screen size (image fills 720×1280 exactly) ──
	# MUSIC  slider:    y=29-37%   x=26-90%
	# SFX    slider:    y=44-52%   x=26-90%
	# VIBRATION toggle: y=58-69%   x=60-87%
	# TUTORIAL  toggle: y=72-82%   x=60-87%
	# SAVE button:      y=84-92%   x=8-92%
	# BACK button:      y=93-100%  x=8-92%

	var W := vp.x
	var H := vp.y

	# ── MUSIC slider ──────────────────────────────────────────────────────────
	_music_slider = _make_image_slider(
		Vector2(W * 0.26, H * 0.29), Vector2(W * 0.64, H * 0.08),
		Global.music_volume, Color(0.22, 0.90, 0.70, 1.0))
	_music_slider.value_changed.connect(_on_music_changed)
	_settings_panel.add_child(_music_slider)

	# ── SFX slider ────────────────────────────────────────────────────────────
	_sfx_slider = _make_image_slider(
		Vector2(W * 0.26, H * 0.44), Vector2(W * 0.64, H * 0.08),
		Global.sfx_volume, Color(0.22, 0.70, 1.00, 1.0))
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_settings_panel.add_child(_sfx_slider)

	# ── VIBRATION toggle ──────────────────────────────────────────────────────
	_vibration_label = _make_state_label(
		Vector2(W * 0.60, H * 0.585), Vector2(W * 0.27, H * 0.10),
		Global.vibration_enabled)
	_settings_panel.add_child(_vibration_label)
	var vib_btn := _make_flat_btn(Vector2(W * 0.58, H * 0.575), Vector2(W * 0.31, H * 0.11))
	vib_btn.pressed.connect(_on_vibration_toggle)
	_settings_panel.add_child(vib_btn)

	# ── TUTORIAL toggle ───────────────────────────────────────────────────────
	_tutorial_label = _make_state_label(
		Vector2(W * 0.60, H * 0.725), Vector2(W * 0.27, H * 0.10),
		not Global.seen_tutorial)
	_settings_panel.add_child(_tutorial_label)
	var tut_btn := _make_flat_btn(Vector2(W * 0.58, H * 0.715), Vector2(W * 0.31, H * 0.11))
	tut_btn.pressed.connect(_on_tutorial_toggle)
	_settings_panel.add_child(tut_btn)

	# ── SAVE button ───────────────────────────────────────────────────────────
	var save_btn := _make_flat_btn(Vector2(W * 0.08, H * 0.845), Vector2(W * 0.84, H * 0.075))
	save_btn.pressed.connect(_on_settings_save)
	_settings_panel.add_child(save_btn)

	# ── BACK button ───────────────────────────────────────────────────────────
	var back_btn := _make_flat_btn(Vector2(W * 0.08, H * 0.928), Vector2(W * 0.84, H * 0.065))
	back_btn.pressed.connect(_close_settings)
	_settings_panel.add_child(back_btn)

	ui_layer.add_child(_settings_panel)

# Invisible HSlider with transparent track — image artwork shows through,
# only the teal fill and thumb are visible.
func _make_image_slider(pos: Vector2, sz: Vector2, initial: float, col: Color) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = initial
	slider.size      = sz
	slider.position  = pos
	var fill := StyleBoxFlat.new()
	fill.bg_color = col.darkened(0.2)
	fill.set_corner_radius_all(4)
	var track := StyleBoxEmpty.new()   # transparent — image track shows through
	slider.add_theme_stylebox_override("fill",   fill)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_color_override("grabber_color", col)
	return slider

# Small teal ON/OFF label overlaid on the toggle artwork
func _make_state_label(pos: Vector2, sz: Vector2, is_on: bool) -> Label:
	var lbl := Label.new()
	lbl.text = "ON" if is_on else "OFF"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color",
		Color(0.22, 0.92, 0.86, 1.0) if is_on else Color(0.55, 0.55, 0.60, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size     = sz
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

# Fully transparent button (no visible style) — just a hit area
func _make_flat_btn(pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.flat = true
	var empty := StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","focus","disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size     = sz
	btn.position = pos
	return btn

# ── Settings callbacks ────────────────────────────────────────────────────────

func _on_music_changed(value: float) -> void:
	Global.music_volume = value
	Global.save_audio_settings()

func _on_sfx_changed(value: float) -> void:
	Global.sfx_volume = value
	Global.apply_sfx_volume()
	Global.save_audio_settings()

func _on_vibration_toggle() -> void:
	Global.vibration_enabled = not Global.vibration_enabled
	if is_instance_valid(_vibration_label):
		_vibration_label.text = "ON" if Global.vibration_enabled else "OFF"
		_vibration_label.add_theme_color_override("font_color",
			Color(0.22, 0.92, 0.86, 1.0) if Global.vibration_enabled else Color(0.55, 0.55, 0.60, 1.0))

func _on_tutorial_toggle() -> void:
	# seen_tutorial=false means "show it again" (ON); flip the flag
	Global.seen_tutorial = not Global.seen_tutorial
	var tutorial_on := not Global.seen_tutorial
	if is_instance_valid(_tutorial_label):
		_tutorial_label.text = "ON" if tutorial_on else "OFF"
		_tutorial_label.add_theme_color_override("font_color",
			Color(0.22, 0.92, 0.86, 1.0) if tutorial_on else Color(0.55, 0.55, 0.60, 1.0))

func _on_settings_save() -> void:
	Global.save_audio_settings()   # persists music, sfx, vibration, seen flags
	_close_settings()

func _on_settings() -> void:
	if _settings_panel == null:
		return
	_settings_panel.visible = true
	var t := _settings_panel.create_tween()
	t.tween_property(_settings_panel, "modulate", Color(1, 1, 1, 1), 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _close_settings() -> void:
	if _settings_panel == null:
		return
	var t := _settings_panel.create_tween()
	t.tween_property(_settings_panel, "modulate", Color(1, 1, 1, 0), 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): _settings_panel.visible = false)

# ── Navigation ────────────────────────────────────────────────────────────────

func _on_continue() -> void:
	Global.selected_level = _continue_level
	Transition.fade_to("res://scenes/game/Game.tscn")

func _on_run() -> void:
	Global.difficulty = 1          # default Medium for quick-start from menu
	Global.carry_score = 0.0
	Global.selected_level = 1
	if not Global.seen_intro:
		Transition.fade_to("res://scenes/menu/IntroScroll.tscn")
	else:
		Transition.fade_to("res://scenes/game/Game.tscn")

func _on_levels() -> void:
	Transition.fade_to("res://scenes/levels/LevelSelect.tscn")
