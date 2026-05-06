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
var _settings_panel: Panel = null
var _music_slider:   HSlider = null
var _sfx_slider:     HSlider = null

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

# ── Settings panel (built in code) ───────────────────────────────────────────

func _build_settings_panel() -> void:
	var vp := get_viewport_rect().size

	_settings_panel = Panel.new()
	_settings_panel.size = Vector2(vp.x * 0.82, 440.0)
	_settings_panel.position = Vector2((vp.x - _settings_panel.size.x) * 0.5, vp.y * 0.28)
	_settings_panel.modulate = Color(1, 1, 1, 0)
	_settings_panel.visible = false
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.04, 0.06, 0.12, 0.96)
	sty.border_color = Color(0.22, 0.78, 0.92, 1.0)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(12)
	_settings_panel.add_theme_stylebox_override("panel", sty)

	# Header
	var header := Label.new()
	header.text = "SETTINGS"
	header.add_theme_font_size_override("font_size", 36)
	header.add_theme_color_override("font_color", Color(0.22, 0.88, 1.0, 1.0))
	header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	header.add_theme_constant_override("shadow_offset_y", 2)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size = Vector2(_settings_panel.size.x, 52.0)
	header.position = Vector2(0, 22.0)
	_settings_panel.add_child(header)

	# Music slider
	_music_slider = _make_slider_row(
		_settings_panel, "Music", 60.0, Global.music_volume,
		Color(0.22, 0.88, 0.70, 1.0))
	_music_slider.value_changed.connect(_on_music_changed)

	# SFX slider
	_sfx_slider = _make_slider_row(
		_settings_panel, "SFX", 170.0, Global.sfx_volume,
		Color(0.22, 0.70, 1.00, 1.0))
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	# "Replay Intro" button — resets seen flags so intro + tutorial play again
	var replay_intro_btn := Button.new()
	replay_intro_btn.text = "REPLAY INTRO"
	replay_intro_btn.custom_minimum_size = Vector2(_settings_panel.size.x - 64.0, 44.0)
	replay_intro_btn.position = Vector2(32.0, 280.0)
	replay_intro_btn.add_theme_font_size_override("font_size", 18)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.08, 0.22, 0.14, 1.0)
	rs.border_color = Color(0.22, 0.82, 0.58, 1.0)
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(6)
	replay_intro_btn.add_theme_stylebox_override("normal", rs)
	replay_intro_btn.add_theme_color_override("font_color", Color(0.22, 0.92, 0.62, 1.0))
	replay_intro_btn.pressed.connect(_on_replay_intro)
	_settings_panel.add_child(replay_intro_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.size = Vector2(180.0, 52.0)
	close_btn.position = Vector2((_settings_panel.size.x - 180.0) * 0.5, 344.0)
	close_btn.add_theme_font_size_override("font_size", 22)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.10, 0.36, 0.60, 1.0)
	cs.border_color = Color(0.22, 0.78, 1.0, 1.0)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	close_btn.pressed.connect(_close_settings)
	_settings_panel.add_child(close_btn)

	ui_layer.add_child(_settings_panel)

func _make_slider_row(parent: Panel, label_text: String, y: float,
		initial: float, col: Color) -> HSlider:
	var pw := parent.size.x
	var margin := 32.0

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95, 1.0))
	lbl.position = Vector2(margin, y + 108.0)
	parent.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial * 100)
	val_lbl.add_theme_font_size_override("font_size", 22)
	val_lbl.add_theme_color_override("font_color", col)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.size = Vector2(70.0, 32.0)
	val_lbl.position = Vector2(pw - margin - 70.0, y + 108.0)
	parent.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.size = Vector2(pw - margin * 2.0, 36.0)
	slider.position = Vector2(margin, y + 144.0)
	var fill_sty := StyleBoxFlat.new()
	fill_sty.bg_color = col
	fill_sty.set_corner_radius_all(4)
	var bg_sty := StyleBoxFlat.new()
	bg_sty.bg_color = Color(0.14, 0.18, 0.28, 1.0)
	bg_sty.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("fill", fill_sty)
	slider.add_theme_stylebox_override("slider", bg_sty)
	slider.value_changed.connect(func(v: float): val_lbl.text = "%d%%" % int(v * 100))
	parent.add_child(slider)
	return slider

# ── Settings callbacks ────────────────────────────────────────────────────────

func _on_replay_intro() -> void:
	Global.reset_seen_flags()
	_close_settings()

func _on_music_changed(value: float) -> void:
	Global.music_volume = value
	Global.save_audio_settings()

func _on_sfx_changed(value: float) -> void:
	Global.sfx_volume = value
	Global.apply_sfx_volume()
	Global.save_audio_settings()

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
	Global.selected_level = 1
	if not Global.seen_intro:
		Transition.fade_to("res://scenes/menu/IntroScroll.tscn")
	else:
		Transition.fade_to("res://scenes/game/Game.tscn")

func _on_levels() -> void:
	Transition.fade_to("res://scenes/levels/LevelSelect.tscn")
