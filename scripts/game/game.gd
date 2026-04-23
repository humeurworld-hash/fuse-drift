extends Node2D
class_name Game

enum GameState { START, PLAYING, DEAD, COMPLETE, PAUSED }

const LEVEL_1_BG_TEXTURE_PATHS := [
	"res://scenes/background/level 1.PNG",
	"res://assets/art/level1/level1_cave_bg.png",
]

const LEVEL_2_BG_TEXTURE_PATHS := [
	"res://scenes/background/level 2.PNG",
	"res://assets/art/level2/background.png",
]

const LEVEL_3_BG_TEXTURE_PATHS := [
	"res://scenes/background/level 3.PNG",
]

@onready var background_fallback: ColorRect = $Background/FallbackBG
@onready var background_art: Sprite2D = $Background/BackgroundArt
@onready var player: Player = $Player
@onready var level1_spawner: Level1Spawner = $Level1Spawner
@onready var level2_spawner: Level2Spawner = $Level2Spawner
@onready var level3_spawner: Level3Spawner = $Level3Spawner
@onready var hazards_root: Node = $Hazards
@onready var pickups_root: Node = $Pickups

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var game_over_sfx: AudioStreamPlayer = $GameOverSfx
@onready var level_complete_sfx: AudioStreamPlayer = $LevelCompleteSfx
@onready var button_click_sfx: AudioStreamPlayer = $ButtonClickSfx
@onready var ui_layer: CanvasLayer = $UI

@onready var life_hub: TextureRect = $UI/LifeHub
@onready var score_hub: TextureRect = $UI/ScoreHub
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var health_label: Label = $UI/HealthLabel
@onready var pause_button: TextureButton = $UI/PauseButton
@onready var wave_banner: Label = $UI/WaveBanner
@onready var dash_button: Button = $UI/DashButton
@onready var pulse_button: Button = $UI/PulseButton
@onready var streak_mult_label: Label = $UI/StreakMultLabel
@onready var streak_sub_label: Label = $UI/StreakSubLabel

@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var game_over_title: Label = $UI/GameOverPanel/GameOverTitle
@onready var score_summary: Label = $UI/GameOverPanel/ScoreSummary
@onready var restart_button: Button = $UI/GameOverPanel/RestartButton
@onready var game_over_menu_button: Button = $UI/GameOverPanel/GameOverMenuButton

@onready var level_clear_panel: Panel = $UI/LevelClearPanel
@onready var clear_title: Label = $UI/LevelClearPanel/ClearTitle
@onready var clear_summary: Label = $UI/LevelClearPanel/ClearSummary
@onready var replay_button: Button = $UI/LevelClearPanel/ReplayButton
@onready var clear_menu_button: Button = $UI/LevelClearPanel/ClearMenuButton

@onready var pause_panel: Panel = $UI/PausePanel
@onready var resume_button: Button = $UI/PausePanel/ResumeButton
@onready var pause_menu_button: Button = $UI/PausePanel/PauseMenuButton

var state: GameState = GameState.START
var score: float = 0.0
var best_score: int = 0
var current_wave: int = 1
var total_waves: int = 4
var current_level: int = 1

# Background parallax / scroll
var _bg_time: float = 0.0
var _bg_scroll_speed: float = 0.04
var _bg_shader: ShaderMaterial = null

# Shard streak multiplier
var shard_streak: int = 0
const STREAK_THRESHOLDS := [15, 10, 5, 0]   # checked in order; first match wins
const STREAK_MULTIPLIERS := [4, 3, 2, 1]
const BASE_SHARD_PTS := 12

func _ready() -> void:
	add_to_group("game")
	_setup_ui()
	_apply_ui_theme()
	_connect_signals()
	match Global.selected_level:
		1: start_level_1()
		2: start_level_2()
		3: start_level_3()
		_: _show_start_screen()

func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	score += delta * 2.0
	update_hud()
	_update_bg_parallax(delta)
	_update_ability_buttons()

func _apply_ui_theme() -> void:
	# ── Panels ───────────────────────────────────────────────────────────────
	_style_panel(game_over_panel,
		Color(0.04, 0.06, 0.11, 0.95),
		Color(0.90, 0.18, 0.08, 1.00), 3)
	_style_panel(level_clear_panel,
		Color(0.04, 0.10, 0.06, 0.95),
		Color(0.92, 0.76, 0.14, 1.00), 3)
	_style_panel(pause_panel,
		Color(0.03, 0.05, 0.10, 0.96),
		Color(0.22, 0.76, 0.90, 1.00), 3)

	# ── Buttons ──────────────────────────────────────────────────────────────
	_style_button(restart_button,
		Color(0.10, 0.36, 0.60, 1.0), Color(0.16, 0.54, 0.84, 1.0),
		Color(0.22, 0.86, 1.00, 1.0))
	_style_button(replay_button,
		Color(0.10, 0.36, 0.60, 1.0), Color(0.16, 0.54, 0.84, 1.0),
		Color(0.22, 0.86, 1.00, 1.0))
	_style_button(resume_button,
		Color(0.10, 0.36, 0.60, 1.0), Color(0.16, 0.54, 0.84, 1.0),
		Color(0.22, 0.86, 1.00, 1.0))
	_style_button(game_over_menu_button,
		Color(0.08, 0.12, 0.20, 1.0), Color(0.13, 0.20, 0.32, 1.0),
		Color(0.28, 0.48, 0.66, 0.9))
	_style_button(clear_menu_button,
		Color(0.08, 0.12, 0.20, 1.0), Color(0.13, 0.20, 0.32, 1.0),
		Color(0.28, 0.48, 0.66, 0.9))
	_style_button(pause_menu_button,
		Color(0.08, 0.12, 0.20, 1.0), Color(0.13, 0.20, 0.32, 1.0),
		Color(0.28, 0.48, 0.66, 0.9))
	# Dash — cyan accent
	_style_button(dash_button,
		Color(0.06, 0.20, 0.38, 1.0), Color(0.10, 0.30, 0.54, 1.0),
		Color(0.22, 0.84, 1.00, 1.0))
	# Pulse — gold accent
	_style_button(pulse_button,
		Color(0.30, 0.22, 0.03, 1.0), Color(0.46, 0.34, 0.05, 1.0),
		Color(1.00, 0.82, 0.18, 1.0))

func _style_panel(panel: Panel, bg: Color, border: Color, bw: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", s)

func _style_button(btn: Button, normal: Color, hover: Color, border: Color) -> void:
	var pressed := Color(normal.r * 0.7, normal.g * 0.7, normal.b * 0.7, 1.0)
	var disabled := Color(normal.r * 0.45, normal.g * 0.45, normal.b * 0.45, 0.7)
	var dborder := Color(border.r * 0.35, border.g * 0.35, border.b * 0.35, 0.5)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(6)
		match state:
			"normal":
				s.bg_color = normal;  s.border_color = border
				s.set_border_width_all(1)
			"hover", "focus":
				s.bg_color = hover;   s.border_color = border
				s.set_border_width_all(2)
			"pressed":
				s.bg_color = pressed; s.border_color = border
				s.set_border_width_all(2)
			"disabled":
				s.bg_color = disabled; s.border_color = dborder
				s.set_border_width_all(1)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color",         Color(0.92, 0.94, 1.00, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 1.00, 1.00, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.78, 0.90, 1.00, 1.0))
	btn.add_theme_color_override("font_disabled_color",Color(0.55, 0.55, 0.60, 1.0))

func _connect_signals() -> void:
	music_player.finished.connect(_on_music_finished)
	pause_button.pressed.connect(_on_pause)
	resume_button.pressed.connect(_on_resume)
	pause_menu_button.pressed.connect(_on_pause_menu)
	restart_button.pressed.connect(_on_restart_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	game_over_menu_button.pressed.connect(_show_start_screen)
	clear_menu_button.pressed.connect(_show_start_screen)
	player.hit.connect(_on_player_hit)
	player.mourk_collected.connect(_on_mourk_collected)
	player.health_changed.connect(_on_health_changed)
	player.dash_activated.connect(_on_dash_activated)
	player.magnet_activated.connect(_on_magnet_activated)
	player.magnet_deactivated.connect(_on_magnet_deactivated)
	dash_button.pressed.connect(_on_dash_pressed)
	pulse_button.pressed.connect(_on_pulse_pressed)
	level1_spawner.wave_started.connect(_on_wave_started)
	level1_spawner.wave_cleared.connect(_on_wave_cleared)
	level1_spawner.level_complete.connect(_on_level_complete)
	level2_spawner.wave_started.connect(_on_wave_started)
	level2_spawner.wave_cleared.connect(_on_wave_cleared)
	level2_spawner.level_complete.connect(_on_level_complete)
	level3_spawner.wave_started.connect(_on_wave_started)
	level3_spawner.wave_cleared.connect(_on_wave_cleared)
	level3_spawner.level_complete.connect(_on_level_complete)

func _setup_ui() -> void:
	score_label.text = "Score: 0"
	best_label.text = "Best: 0"
	wave_label.text = "Wave 1/4"
	health_label.text = ""
	score_hub.visible = false
	life_hub.visible = false
	score_label.visible = false
	best_label.visible = false
	wave_label.visible = false
	health_label.visible = false
	pause_button.visible = false
	game_over_panel.visible = false
	score_summary.text = ""
	restart_button.text = "RESTART"
	game_over_menu_button.text = "MENU"
	level_clear_panel.visible = false
	clear_summary.text = ""
	replay_button.text = "REPLAY"
	clear_menu_button.text = "MENU"
	pause_panel.visible = false
	wave_banner.visible = false
	wave_banner.modulate = Color(1, 1, 1, 0)
	dash_button.visible = false
	pulse_button.visible = false
	streak_mult_label.visible = false
	streak_sub_label.visible = false

func _setup_background(texture_paths: Array) -> void:
	var viewport_size := get_viewport_rect().size
	background_fallback.color = Color("07151b")
	background_fallback.position = Vector2.ZERO
	background_fallback.size = viewport_size
	background_fallback.visible = true
	background_art.visible = false
	_bg_time = 0.0
	for texture_path in texture_paths:
		if ResourceLoader.exists(texture_path):
			var tex: Texture2D = load(texture_path)
			if tex != null:
				background_art.texture = tex
				background_art.position = viewport_size * 0.5
				var tex_size := tex.get_size()
				# Scale slightly over-fit (1.08×) so horizontal parallax shift
				# never reveals a black edge at the sides.
				var fit_scale := maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y) * 1.08
				background_art.scale = Vector2.ONE * fit_scale
				background_art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				# Build (or reuse) the scroll shader material
				if _bg_shader == null:
					var shader: Shader = load("res://shaders/bg_scroll.gdshader")
					_bg_shader = ShaderMaterial.new()
					_bg_shader.shader = shader
				_bg_shader.set_shader_parameter("scroll_speed", _bg_scroll_speed)
				_bg_shader.set_shader_parameter("scroll_offset", 0.0)
				_bg_shader.set_shader_parameter("parallax_x", 0.0)
				background_art.material = _bg_shader
				background_art.visible = true
				background_fallback.visible = false
				return

func _update_bg_parallax(delta: float) -> void:
	if not background_art.visible or _bg_shader == null:
		return
	_bg_time += delta
	_bg_shader.set_shader_parameter("scroll_offset", _bg_time)
	# Map player X to -0.5 … +0.5 relative to screen centre
	var vp_w := get_viewport_rect().size.x
	var px := (player.position.x - vp_w * 0.5) / vp_w  # −0.5 left … +0.5 right
	_bg_shader.set_shader_parameter("parallax_x", px)

func _show_start_screen() -> void:
	get_tree().paused = false
	Transition.fade_to("res://scenes/menu/Menu.tscn")

func _on_restart_pressed() -> void:
	button_click_sfx.play()
	_restart_current_level()

func _on_replay_pressed() -> void:
	button_click_sfx.play()
	_restart_current_level()

func _restart_current_level() -> void:
	if state == GameState.COMPLETE and current_level == 1:
		start_level_2()
	elif state == GameState.COMPLETE and current_level == 2:
		start_level_3()
	elif current_level == 3:
		start_level_3()
	elif current_level == 2:
		start_level_2()
	else:
		start_level_1()

func _on_pause() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	get_tree().paused = true
	pause_panel.visible = true
	pause_button.visible = false

func _on_resume() -> void:
	state = GameState.PLAYING
	get_tree().paused = false
	pause_panel.visible = false
	pause_button.visible = true

func _on_pause_menu() -> void:
	get_tree().paused = false
	_show_start_screen()

func start_level_1() -> void:
	current_level = 1
	best_score = Global.get_best(1)
	state = GameState.PLAYING
	score = 0.0
	shard_streak = 0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(1)
	game_over_panel.visible = false
	level_clear_panel.visible = false
	pause_panel.visible = false
	score_hub.visible = true
	life_hub.visible = false
	score_label.visible = true
	best_label.visible = true
	wave_label.visible = true
	health_label.visible = false
	pause_button.visible = true
	dash_button.visible = true
	pulse_button.visible = true
	streak_mult_label.visible = true
	streak_sub_label.visible = true
	_reset_streak_display()
	_bg_scroll_speed = 0.03  # cave: slow, heavy drift
	_setup_background(LEVEL_1_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	level1_spawner.start_run()
	update_hud()

func start_level_2() -> void:
	current_level = 2
	best_score = Global.get_best(2)
	state = GameState.PLAYING
	score = 0.0
	shard_streak = 0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(3)
	game_over_panel.visible = false
	level_clear_panel.visible = false
	pause_panel.visible = false
	score_hub.visible = true
	life_hub.visible = true
	score_label.visible = true
	best_label.visible = true
	wave_label.visible = true
	health_label.visible = true
	pause_button.visible = true
	dash_button.visible = true
	pulse_button.visible = true
	streak_mult_label.visible = true
	streak_sub_label.visible = true
	_reset_streak_display()
	_bg_scroll_speed = 0.05  # canvas: medium pace
	_setup_background(LEVEL_2_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	level2_spawner.start_run()
	_update_health_display(3)
	update_hud()

func start_level_3() -> void:
	current_level = 3
	best_score = Global.get_best(3)
	state = GameState.PLAYING
	score = 0.0
	shard_streak = 0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(3)
	game_over_panel.visible = false
	level_clear_panel.visible = false
	pause_panel.visible = false
	score_hub.visible = true
	life_hub.visible = true
	score_label.visible = true
	best_label.visible = true
	wave_label.visible = true
	health_label.visible = true
	pause_button.visible = true
	dash_button.visible = true
	pulse_button.visible = true
	streak_mult_label.visible = true
	streak_sub_label.visible = true
	_reset_streak_display()
	_bg_scroll_speed = 0.07  # loops: faster, more frantic
	_setup_background(LEVEL_3_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	level3_spawner.start_run()
	_update_health_display(3)
	update_hud()

func update_hud() -> void:
	score_label.text = "Score: %d" % int(floor(score))
	best_label.text = "Best: %d" % best_score
	wave_label.text = "Wave %d/%d" % [current_wave, total_waves]

func _update_health_display(hp: int) -> void:
	var s := ""
	for i in player.max_health:
		s += "♥ " if i < hp else "· "
	health_label.text = s.strip_edges()

func clear_run_objects() -> void:
	for child in hazards_root.get_children():
		child.queue_free()
	for child in pickups_root.get_children():
		child.queue_free()

func _screen_shake(intensity: float = 7.0, duration: float = 0.28) -> void:
	var origin := position
	var tween := create_tween()
	var steps := 6
	var step_time := duration / steps
	for i in steps:
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", origin + offset, step_time)
	tween.tween_property(self, "position", origin, step_time * 0.5)

func _on_wave_started(wave: int, total: int) -> void:
	current_wave = wave
	total_waves = total
	update_hud()
	_hide_wave_banner()

func _on_wave_cleared(cleared_wave: int) -> void:
	score += 60.0
	update_hud()
	# Don't show a banner after the last wave — level_complete fires next
	var next_wave := cleared_wave + 1
	if next_wave <= total_waves:
		_show_wave_banner(next_wave)

func _show_wave_banner(next_wave: int) -> void:
	wave_banner.text = "WAVE  %d" % next_wave
	# Slide in from slightly below centre, then settle
	wave_banner.position = Vector2(0.0, 600.0)
	wave_banner.visible = true
	wave_banner.modulate = Color(1, 1, 1, 0)
	var tween := wave_banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave_banner, "modulate", Color(1, 1, 1, 1), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave_banner, "position:y", 560.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_wave_banner() -> void:
	if not wave_banner.visible:
		return
	var tween := wave_banner.create_tween()
	tween.tween_property(wave_banner, "modulate", Color(1, 1, 1, 0), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): wave_banner.visible = false)

# Called by RockHazard when a rock passes within near-miss range of Fuse
func on_near_miss(world_pos: Vector2) -> void:
	if state != GameState.PLAYING:
		return
	const NEAR_MISS_PTS := 5
	score += NEAR_MISS_PTS
	update_hud()
	_spawn_float_text("+%d  NEAR!" % NEAR_MISS_PTS, world_pos + Vector2(0, -30))

func _on_dash_pressed() -> void:
	if state != GameState.PLAYING:
		return
	player.try_dash()

func _on_pulse_pressed() -> void:
	if state != GameState.PLAYING:
		return
	if not player.can_magnet():
		return
	# Cost: reset the shard streak (risk — you lose your multiplier)
	shard_streak = 0
	update_hud()
	_animate_streak_reset()
	player.try_magnet()

func _on_dash_activated() -> void:
	pass  # visual is handled entirely inside player.gd

func _on_magnet_activated() -> void:
	pass  # visual handled in player.gd; button UI updates each frame

func _on_magnet_deactivated() -> void:
	pass

func _update_ability_buttons() -> void:
	# ── Dash button ──────────────────────────────────────────────────────────
	var dc := player.get_dash_cooldown()
	if dc > 0.0:
		dash_button.text = "DASH\n%.1fs" % dc
		dash_button.disabled = true
		dash_button.modulate = Color(0.55, 0.55, 0.55, 1.0)
	else:
		dash_button.text = "GHOST\nDASH"
		dash_button.disabled = false
		dash_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# ── Pulse button ─────────────────────────────────────────────────────────
	var mc := player.get_magnet_cooldown()
	if mc > 0.0:
		pulse_button.text = "PULSE\n%.1fs" % mc
		pulse_button.disabled = true
		pulse_button.modulate = Color(0.55, 0.55, 0.55, 1.0)
	else:
		var mult := _get_shard_multiplier()
		if shard_streak > 0:
			pulse_button.text = "SHARD\nPULSE  ×%d↓" % mult
		else:
			pulse_button.text = "SHARD\nPULSE"
		pulse_button.disabled = false
		pulse_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _get_shard_multiplier() -> int:
	for i in STREAK_THRESHOLDS.size():
		if shard_streak >= STREAK_THRESHOLDS[i]:
			return STREAK_MULTIPLIERS[i]
	return 1

func _on_mourk_collected(_base_points: int, world_pos: Vector2) -> void:
	if state != GameState.PLAYING:
		return
	shard_streak += 1
	var mult := _get_shard_multiplier()
	var pts := BASE_SHARD_PTS * mult
	score += pts
	update_hud()
	_animate_streak_collect()
	var label_text := "+%d" % pts
	if mult > 1:
		label_text += "  ×%d" % mult
	_spawn_float_text(label_text, world_pos, _streak_font_size(mult), _streak_color(mult))

# ── Streak display ────────────────────────────────────────────────────────────

func _streak_color(mult: int) -> Color:
	match mult:
		1: return Color(0.72, 0.72, 0.72, 0.50)   # dim grey  — not active yet
		2: return Color(0.30, 1.00, 0.88, 1.00)   # cyan
		3: return Color(1.00, 0.88, 0.22, 1.00)   # gold
		4: return Color(1.00, 0.46, 0.10, 1.00)   # hot orange
		_: return Color(1.00, 1.00, 1.00, 1.00)

func _streak_font_size(mult: int) -> int:
	# Float pop-ups grow with the multiplier so high combos feel louder
	return 38 + (mult - 1) * 10   # ×1→38  ×2→48  ×3→58  ×4→68

func _next_streak_threshold() -> int:
	# STREAK_THRESHOLDS = [15, 10, 5, 0]  (descending)
	# Return the lowest threshold above current streak; -1 if already maxed
	var next := -1
	for t: int in STREAK_THRESHOLDS:
		if t > shard_streak:
			next = t
	return next

func _reset_streak_display() -> void:
	streak_mult_label.scale = Vector2.ONE
	streak_mult_label.text = "×1"
	streak_mult_label.modulate = _streak_color(1)
	streak_sub_label.text = "0  →  5"
	streak_sub_label.modulate = Color(0.7, 0.7, 0.7, 0.6)

func _animate_streak_collect() -> void:
	var mult := _get_shard_multiplier()
	var color := _streak_color(mult)

	# Update text
	streak_mult_label.text = "×%d" % mult
	streak_mult_label.modulate = color
	var next_t := _next_streak_threshold()
	if next_t < 0:
		streak_sub_label.text = "MAX COMBO"
		streak_sub_label.modulate = Color(color.r, color.g, color.b, 0.9)
	else:
		streak_sub_label.text = "%d  →  %d" % [shard_streak, next_t]
		streak_sub_label.modulate = Color(0.85, 0.85, 0.85, 0.75)

	# Scale punch: pop up then spring back elastically from the centre pivot
	streak_mult_label.scale = Vector2(1.38, 1.38)
	var tween := streak_mult_label.create_tween()
	tween.tween_property(streak_mult_label, "scale", Vector2.ONE, 0.38) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _animate_streak_reset() -> void:
	# Flash red, then dim back to ×1 grey
	var tween := streak_mult_label.create_tween()
	tween.tween_property(streak_mult_label, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.07)
	tween.tween_property(streak_mult_label, "modulate", _streak_color(1), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	streak_mult_label.text = "×1"
	streak_sub_label.text = "0  →  5"
	streak_sub_label.modulate = Color(0.7, 0.7, 0.7, 0.6)

# ── Float text ────────────────────────────────────────────────────────────────

func _spawn_float_text(text: String, world_pos: Vector2,
		font_size: int = 42, color: Color = Color(0.3, 1.0, 0.95, 1.0)) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.position = world_pos - Vector2(36.0, 52.0)
	# Scale punch in
	label.scale = Vector2(1.35, 1.35)
	ui_layer.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", label.position + Vector2(0, -84), 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.58).set_delay(0.22)
	tween.chain().tween_callback(label.queue_free)

func _on_health_changed(new_health: int) -> void:
	_update_health_display(new_health)
	_screen_shake(6.0, 0.22)

func _on_player_hit() -> void:
	if state != GameState.PLAYING:
		return
	shard_streak = 0
	_animate_streak_reset()
	state = GameState.DEAD
	level1_spawner.stop_run()
	level2_spawner.stop_run()
	level3_spawner.stop_run()
	player.disable_control()
	clear_run_objects()
	pause_button.visible = false
	dash_button.visible = false
	pulse_button.visible = false
	streak_mult_label.visible = false
	streak_sub_label.visible = false
	score_hub.visible = false
	life_hub.visible = false
	wave_banner.visible = false
	game_over_sfx.play()
	_screen_shake(12.0, 0.4)
	var final_score := int(floor(score))
	_update_best_score(final_score)
	var level_name := "Level %d" % current_level
	score_summary.text = "%s  ·  Wave %d\n\nScore   %d\nBest    %d" % [level_name, current_wave, final_score, best_score]
	restart_button.text = "RESTART LEVEL %d" % current_level
	game_over_panel.visible = true

func _on_level_complete() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.COMPLETE
	score += 300.0
	level1_spawner.stop_run()
	level2_spawner.stop_run()
	level3_spawner.stop_run()
	player.disable_control()
	clear_run_objects()
	pause_button.visible = false
	dash_button.visible = false
	pulse_button.visible = false
	streak_mult_label.visible = false
	streak_sub_label.visible = false
	score_hub.visible = false
	life_hub.visible = false
	wave_banner.visible = false
	level_complete_sfx.play()
	if current_level == 1:
		Global.unlock_level(2)
	elif current_level == 2:
		Global.unlock_level(3)
	var final_score := int(floor(score))
	_update_best_score(final_score)
	var next_line: String
	match current_level:
		1: next_line = "Level 2 — The Canvas awaits!"
		2: next_line = "Level 3 — The Loops awaits!"
		_: next_line = "More levels coming soon."
	clear_title.text = "LEVEL %d  CLEAR" % current_level
	clear_summary.text = "Score   %d\nBest    %d\n\n%s" % [final_score, best_score, next_line]
	match current_level:
		1: replay_button.text = "PLAY LEVEL 2"
		2: replay_button.text = "PLAY LEVEL 3"
		_: replay_button.text = "REPLAY LEVEL %d" % current_level
	level_clear_panel.visible = true
	update_hud()

func _on_music_finished() -> void:
	music_player.play()

func _update_best_score(final_score: int) -> void:
	Global.save_best(current_level, final_score)
	best_score = Global.get_best(current_level)
