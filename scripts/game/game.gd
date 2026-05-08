extends Node2D
class_name Game

enum GameState { START, PLAYING, DEAD, COMPLETE, PAUSED }

const LEVEL_1_BG_TEXTURE_PATHS := [
	"res://scenes/background/new level 1.png",
	"res://scenes/background/level 1.PNG",
	"res://assets/art/level1/level1_cave_bg.png",
]

const LEVEL_2_BG_TEXTURE_PATHS := [
	"res://scenes/background/new level 2.png",
	"res://scenes/background/level 2.PNG",
	"res://assets/art/level2/background.png",
]

const LEVEL_3_BG_TEXTURE_PATHS := [
	"res://scenes/background/new level 3.png",
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
@onready var fuse_sfx: AudioStreamPlayer = $FuseSfx
@onready var jackpot_sfx: AudioStreamPlayer = $JackpotSfx
@onready var slow_time_sfx: AudioStreamPlayer = $SlowTimeSfx
@onready var green_sfx: AudioStreamPlayer = $GreenSfx
@onready var ui_layer: CanvasLayer = $UI

@onready var life_hub: TextureRect = $UI/LifeHub
@onready var score_hub: TextureRect = $UI/ScoreHub
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var score_number: SpriteNumber = $UI/ScoreNumber
@onready var best_number: SpriteNumber = $UI/BestNumber
@onready var shard_counter_bg: TextureRect = $UI/ShardCounterBG
@onready var wave_label: Label = $UI/WaveLabel
@onready var health_label: Label = $UI/HealthLabel
@onready var pause_button: TextureButton = $UI/PauseButton
@onready var wave_banner: Label = $UI/WaveBanner
@onready var dash_button: TextureButton = $UI/DashButton
@onready var dash_label: Label = $UI/DashButton/DashLabel
@onready var pulse_button: TextureButton = $UI/PulseButton
@onready var pulse_label: Label = $UI/PulseButton/PulseLabel
@onready var streak_mult_label: Label = $UI/StreakMultLabel
@onready var streak_sub_label: Label = $UI/StreakSubLabel
@onready var fuse_banner: Label = $UI/FuseStateBanner
@onready var fuse_character_sprite: Sprite2D = $UI/FuseCharacterSprite

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

# Fuse State — triggered at every 10 consecutive shards
var fuse_state_active: bool = false
var hazard_speed_mult: float = 1.0
var _fuse_timer: float = 0.0
const FUSE_DURATION := 5.0          # short and punchy
const FUSE_HAZARD_MULT := 0.35      # hazards crawl — very dramatic
const FUSE_STREAK_TRIGGER := 10

# Fuse vignette — built once, reused each activation
var _fuse_overlay: ColorRect = null
var _fuse_borders: Array[ColorRect] = []
var _fuse_pulse_tween: Tween = null

# Active-effect HUD pills (jackpot + slow-time countdown indicators)
const PILL_W := 210.0
const PILL_H := 44.0
const PILL_BAR_H := 5.0
var _jackpot_pill: Panel = null
var _jackpot_pill_label: Label = null
var _jackpot_pill_bar: ColorRect = null
var _slow_pill: Panel = null
var _slow_pill_label: Label = null
var _slow_pill_bar: ColorRect = null

# Jackpot — Gold shard, ×3 multiplier for 8s
var jackpot_active: bool = false
var _jackpot_timer: float = 0.0
const JACKPOT_DURATION := 8.0
const JACKPOT_MULT := 3

# Slow-time — Purple shard, hazards at 65% for 4s
var slow_time_active: bool = false
var _slow_time_timer: float = 0.0
const SLOW_TIME_DURATION := 4.0
const SLOW_TIME_HAZARD_MULT := 0.65

func _ready() -> void:
	add_to_group("game")
	_setup_ui()
	_apply_ui_theme()
	_connect_signals()
	_build_fuse_vignette()
	_build_effect_huds()
	music_player.volume_db = linear_to_db(maxf(Global.music_volume, 0.001))
	match Global.selected_level:
		1: start_level_1()
		2: start_level_2()
		3: start_level_3()
		_: _show_start_screen()

func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	score += delta * 2.0 * Global.DIFFICULTY_SCORE_MULT[clampi(Global.difficulty, 0, 2)]
	update_hud()
	_update_bg_parallax(delta)
	_update_ability_buttons()
	# Fuse State countdown
	if fuse_state_active:
		_fuse_timer -= delta
		_update_fuse_countdown()
		if _fuse_timer <= 0.0:
			_deactivate_fuse_state()
	# Jackpot countdown
	if jackpot_active:
		_jackpot_timer -= delta
		_update_jackpot_pill()
		if _jackpot_timer <= 0.0:
			_deactivate_jackpot()
	# Slow-time countdown
	if slow_time_active:
		_slow_time_timer -= delta
		_update_slow_pill()
		if _slow_time_timer <= 0.0:
			_deactivate_slow_time()

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
	# Dash and Pulse use artwork textures — no style override needed

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
	player.rewinder_hit.connect(_on_rewinder_hit)
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
	# Panels must process even when get_tree().paused = true so their
	# buttons always receive input regardless of pause state.
	game_over_panel.process_mode   = Node.PROCESS_MODE_ALWAYS
	level_clear_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.process_mode       = Node.PROCESS_MODE_ALWAYS

	score_label.visible = false   # replaced by ScoreNumber
	best_label.visible = false    # replaced by BestNumber
	score_label.text = "Score: 0"
	best_label.text = "Best: 0"
	wave_label.text = "Wave 1/4"
	health_label.text = ""
	score_hub.visible = false
	life_hub.visible = false
	shard_counter_bg.visible = false
	score_number.visible = false
	best_number.visible = false
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
	fuse_banner.visible = false
	fuse_character_sprite.visible = false
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
	Global.carry_score = 0.0   # fresh run if they go through level select
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
	elif state == GameState.COMPLETE and current_level == 3:
		# Full game beaten — fresh run from the very beginning
		Global.carry_score = 0.0
		start_level_1()
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
	get_tree().paused = false   # always clear any leftover pause
	current_level = 1
	best_score = Global.get_best(1)
	state = GameState.PLAYING
	score = 0.0
	Global.carry_score = 0.0
	shard_streak = 0
	fuse_state_active = false
	hazard_speed_mult = 1.0
	_fuse_timer = 0.0
	jackpot_active = false
	_jackpot_timer = 0.0
	slow_time_active = false
	_slow_time_timer = 0.0
	if _jackpot_pill != null: _jackpot_pill.modulate = Color(1, 1, 1, 0)
	if _slow_pill   != null: _slow_pill.modulate   = Color(1, 1, 1, 0)
	level1_spawner.hazard_speed_mult = 1.0
	level2_spawner.hazard_speed_mult = 1.0
	level3_spawner.hazard_speed_mult = 1.0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(1)
	player.exit_fuse_state()
	game_over_panel.visible = false
	level_clear_panel.visible = false
	pause_panel.visible = false
	score_hub.visible = false
	life_hub.visible = false
	shard_counter_bg.visible = true
	score_label.visible = false
	score_number.visible = true
	best_label.visible = false
	best_number.visible = true
	wave_label.visible = true
	health_label.visible = false
	pause_button.visible = true
	dash_button.visible = true
	pulse_button.visible = true
	streak_mult_label.visible = true
	streak_sub_label.visible = true
	fuse_banner.visible = false
	fuse_character_sprite.visible = false
	_reset_streak_display()
	_bg_scroll_speed = 0.03  # cave: slow, heavy drift
	_setup_background(LEVEL_1_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	if not Global.seen_tutorial:
		_show_tutorial()
	else:
		level1_spawner.start_run()
	update_hud()

func start_level_2() -> void:
	get_tree().paused = false   # always clear any leftover pause
	current_level = 2
	best_score = Global.get_best(2)
	state = GameState.PLAYING
	score = Global.carry_score
	shard_streak = 0
	fuse_state_active = false
	hazard_speed_mult = 1.0
	_fuse_timer = 0.0
	jackpot_active = false
	_jackpot_timer = 0.0
	slow_time_active = false
	_slow_time_timer = 0.0
	if _jackpot_pill != null: _jackpot_pill.modulate = Color(1, 1, 1, 0)
	if _slow_pill   != null: _slow_pill.modulate   = Color(1, 1, 1, 0)
	level1_spawner.hazard_speed_mult = 1.0
	level2_spawner.hazard_speed_mult = 1.0
	level3_spawner.hazard_speed_mult = 1.0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(3)
	player.exit_fuse_state()
	game_over_panel.visible = false
	level_clear_panel.visible = false
	pause_panel.visible = false
	score_hub.visible = false
	life_hub.visible = false
	shard_counter_bg.visible = true
	score_label.visible = false
	score_number.visible = true
	best_label.visible = false
	best_number.visible = true
	wave_label.visible = true
	health_label.visible = true
	pause_button.visible = true
	dash_button.visible = true
	pulse_button.visible = true
	streak_mult_label.visible = true
	streak_sub_label.visible = true
	fuse_banner.visible = false
	fuse_character_sprite.visible = false
	_reset_streak_display()
	_bg_scroll_speed = 0.05  # canvas: medium pace
	_setup_background(LEVEL_2_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	level2_spawner.start_run()
	_update_health_display(3)
	update_hud()

func start_level_3() -> void:
	get_tree().paused = false   # always clear any leftover pause
	current_level = 3
	best_score = Global.get_best(3)
	state = GameState.PLAYING
	score = Global.carry_score
	shard_streak = 0
	fuse_state_active = false
	hazard_speed_mult = 1.0
	_fuse_timer = 0.0
	jackpot_active = false
	_jackpot_timer = 0.0
	slow_time_active = false
	_slow_time_timer = 0.0
	if _jackpot_pill != null: _jackpot_pill.modulate = Color(1, 1, 1, 0)
	if _slow_pill   != null: _slow_pill.modulate   = Color(1, 1, 1, 0)
	level1_spawner.hazard_speed_mult = 1.0
	level2_spawner.hazard_speed_mult = 1.0
	level3_spawner.hazard_speed_mult = 1.0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(3)
	player.exit_fuse_state()
	game_over_panel.visible = false
	level_clear_panel.visible = false
	pause_panel.visible = false
	score_hub.visible = false
	life_hub.visible = false
	shard_counter_bg.visible = true
	score_label.visible = false
	score_number.visible = true
	best_label.visible = false
	best_number.visible = true
	wave_label.visible = true
	health_label.visible = true
	pause_button.visible = true
	dash_button.visible = true
	pulse_button.visible = true
	streak_mult_label.visible = true
	streak_sub_label.visible = true
	fuse_banner.visible = false
	fuse_character_sprite.visible = false
	_reset_streak_display()
	_bg_scroll_speed = 0.07  # loops: faster, more frantic
	_setup_background(LEVEL_3_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	level3_spawner.start_run()
	_update_health_display(3)
	update_hud()

func update_hud() -> void:
	var s := int(floor(score))
	score_label.text = "Score: %d" % s
	best_label.text = "Best: %d" % best_score
	wave_label.text = "Wave %d/%d" % [current_wave, total_waves]
	score_number.set_value(s)
	best_number.set_value(best_score)

func _update_health_display(hp: int) -> void:
	var s := ""
	for i in player.max_health:
		s += "♥  " if i < hp else "·  "
	health_label.text = s.strip_edges()
	# Keep hearts large and vibrant; lost hearts dim
	var alive_col := Color(1.00, 0.30, 0.38, 1.0)  # vivid red-pink
	var empty_col := Color(0.40, 0.40, 0.45, 0.55)  # dim grey
	# Lerp colour toward empty the more hp is lost
	var ratio := float(hp) / float(max(player.max_health, 1))
	health_label.modulate = alive_col.lerp(empty_col, 1.0 - ratio)
	health_label.add_theme_font_size_override("font_size", 34)

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
	_flash_wave_start(wave)
	# Wave 1 has no predecessor wave to show its banner, so show it here.
	# Waves 2–4 already get their banner from _on_wave_cleared().
	if wave == 1:
		_show_wave_banner(wave)

func _flash_wave_start(wave: int) -> void:
	# Colour escalates per wave: teal → orange → purple → gold
	var colors: Array[Color] = [
		Color(0.20, 0.90, 0.85, 0.25),  # wave 1 — teal
		Color(0.95, 0.52, 0.10, 0.28),  # wave 2 — orange
		Color(0.65, 0.20, 0.95, 0.28),  # wave 3 — purple
		Color(1.00, 0.82, 0.10, 0.32),  # wave 4 — gold
	]
	var idx: int = clampi(wave - 1, 0, colors.size() - 1)
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = colors[idx]
	flash.size = get_viewport_rect().size
	flash.position = Vector2.ZERO
	flash.modulate = Color(1, 1, 1, 0)
	ui_layer.add_child(flash)
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "modulate", Color(1, 1, 1, 1), 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)

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

func _on_rewinder_hit(world_pos: Vector2) -> void:
	if state != GameState.PLAYING:
		return
	const REWIND_SCORE_PENALTY := 30
	score = maxf(score - float(REWIND_SCORE_PENALTY), 0.0)
	# Rewind breaks the shard streak
	shard_streak = 0
	_animate_streak_reset()
	update_hud()
	_spawn_float_text("−%d  REWIND!" % REWIND_SCORE_PENALTY,
		world_pos + Vector2(0, -48), 44, Color(0.25, 0.90, 1.00, 1.0))
	# Cyan screen flash — distinct from the red hit flash
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.18, 0.85, 1.00, 0.30)
	flash.size = get_viewport_rect().size
	flash.position = Vector2.ZERO
	flash.modulate = Color(1, 1, 1, 0)
	ui_layer.add_child(flash)
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "modulate", Color(1, 1, 1, 1), 0.10)
	tween.tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.50)
	tween.tween_callback(flash.queue_free)

func _show_tutorial() -> void:
	var tut_scene: PackedScene = load("res://scenes/game/Tutorial.tscn")
	var tut: TutorialCard = tut_scene.instantiate()
	add_child(tut)
	tut.tutorial_done.connect(func():
		Global.seen_tutorial = true
		Global.save_seen_flags()
		level1_spawner.start_run()
	)

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
		dash_label.text = "%.1fs" % dc
		dash_button.disabled = true
		dash_button.modulate = Color(0.50, 0.50, 0.50, 0.75)
		dash_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		dash_label.text = ""
		dash_button.disabled = false
		dash_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# ── Pulse button ─────────────────────────────────────────────────────────
	var mc := player.get_magnet_cooldown()
	if mc > 0.0:
		pulse_label.text = "%.1fs" % mc
		pulse_button.disabled = true
		pulse_button.modulate = Color(0.50, 0.50, 0.50, 0.75)
		pulse_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		var mult := _get_shard_multiplier()
		pulse_label.text = "×%d" % mult if shard_streak > 0 else ""
		pulse_button.disabled = false
		pulse_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _get_shard_multiplier() -> int:
	for i in STREAK_THRESHOLDS.size():
		if shard_streak >= STREAK_THRESHOLDS[i]:
			return STREAK_MULTIPLIERS[i]
	return 1

func _on_mourk_collected(base_points: int, world_pos: Vector2, shard_color: int) -> void:
	if state != GameState.PLAYING:
		return
	shard_streak += 1
	var mult := _get_shard_multiplier()
	var pts := base_points * mult
	if jackpot_active:
		pts *= JACKPOT_MULT
	pts *= Global.DIFFICULTY_SCORE_MULT[clampi(Global.difficulty, 0, 2)]
	score += pts
	update_hud()
	# Fuse State — trigger at every 10th consecutive shard
	if shard_streak % FUSE_STREAK_TRIGGER == 0:
		if fuse_state_active:
			_fuse_timer = FUSE_DURATION
			_show_fuse_banner()
		else:
			_activate_fuse_state()
	_animate_streak_collect()
	# Color-specific effects
	match shard_color:
		MourkShard.ShardColor.ORANGE:
			shard_streak += 5
			if shard_streak % FUSE_STREAK_TRIGGER == 0:
				if fuse_state_active:
					_fuse_timer = FUSE_DURATION
					_show_fuse_banner()
				else:
					_activate_fuse_state()
			_animate_streak_collect()
		MourkShard.ShardColor.PURPLE:
			_apply_slow_time()
		MourkShard.ShardColor.GREEN:
			_apply_green_effect(world_pos)
		MourkShard.ShardColor.GOLD:
			_activate_jackpot(world_pos)
	var label_text := "+%d" % pts
	if mult > 1:
		label_text += "  ×%d" % mult
	var text_color := _shard_color_for_points(base_points).lerp(_streak_color(mult), 0.45)
	_spawn_float_text(label_text, world_pos, _streak_font_size(mult), text_color)

func _shard_color_for_points(pts: int) -> Color:
	if pts >= 55:
		return Color(1.00, 0.88, 0.15, 1.0)   # gold
	elif pts >= 40:
		return Color(0.72, 0.28, 1.00, 1.0)   # purple
	elif pts >= 25:
		return Color(1.00, 0.55, 0.10, 1.0)   # orange
	elif pts >= 15:
		return Color(0.25, 1.00, 0.45, 1.0)   # green
	else:
		return Color(0.30, 0.90, 0.85, 1.0)   # teal

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

	if fuse_state_active:
		# During Fuse, label locks to "FUSE" — countdown updated each frame
		streak_mult_label.text = "FUSE"
		streak_mult_label.modulate = Color(0.15, 0.95, 0.88, 1.0)
		streak_sub_label.text = "FUSE  %.1fs" % _fuse_timer
		streak_sub_label.modulate = Color(0.25, 1.00, 0.92, 0.95)
	else:
		streak_mult_label.text = "×%d" % mult
		streak_mult_label.modulate = color
		var next_t := _next_streak_threshold()
		if next_t < 0:
			streak_sub_label.text = "MAX COMBO"
			streak_sub_label.modulate = Color(color.r, color.g, color.b, 0.9)
		else:
			streak_sub_label.text = "%d  →  %d" % [shard_streak, next_t]
			streak_sub_label.modulate = Color(0.85, 0.85, 0.85, 0.75)

	# Scale punch
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
	# Pulse health label — scale + red flash on damage
	if is_instance_valid(health_label) and health_label.visible:
		health_label.modulate = Color(1.0, 0.18, 0.18, 1.0)
		health_label.scale = Vector2(1.45, 1.45)
		var tween: Tween = health_label.create_tween()
		tween.set_parallel(true)
		tween.tween_property(health_label, "scale", Vector2.ONE, 0.50) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(health_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.50) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_player_hit() -> void:
	if state != GameState.PLAYING:
		return
	shard_streak = 0
	_animate_streak_reset()
	if fuse_state_active:
		_deactivate_fuse_state()
	if jackpot_active:
		_deactivate_jackpot()
	if slow_time_active:
		_deactivate_slow_time()
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
	shard_counter_bg.visible = false
	score_number.visible = false
	best_number.visible = false
	life_hub.visible = false
	wave_banner.visible = false
	fuse_banner.visible = false
	fuse_character_sprite.visible = false
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
	if fuse_state_active:
		_deactivate_fuse_state()
	if jackpot_active:
		_deactivate_jackpot()
	if slow_time_active:
		_deactivate_slow_time()
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
	shard_counter_bg.visible = false
	score_number.visible = false
	best_number.visible = false
	life_hub.visible = false
	wave_banner.visible = false
	fuse_banner.visible = false
	fuse_character_sprite.visible = false
	level_complete_sfx.play()
	if current_level == 1:
		Global.unlock_level(2)
	elif current_level == 2:
		Global.unlock_level(3)
	var final_score := int(floor(score))
	_update_best_score(final_score)
	var incoming_carry := int(Global.carry_score)   # what arrived from previous level
	Global.carry_score = score                      # pass full total into next level
	var next_line: String
	match current_level:
		1: next_line = "Level 2 — The Verge awaits!"
		2: next_line = "Level 3 — The Loops awaits!"
		_: next_line = "More levels coming soon."
	clear_title.text = "LEVEL %d  CLEAR" % current_level
	if incoming_carry > 0:
		var earned := final_score - incoming_carry
		clear_summary.text = "This level   +%d\nCarried          %d\nTotal            %d\nBest             %d\n\n%s" % [
			earned, incoming_carry, final_score, best_score, next_line]
	else:
		clear_summary.text = "Score   %d\nBest    %d\n\n%s" % [final_score, best_score, next_line]
	match current_level:
		1: replay_button.text = "PLAY LEVEL 2"
		2: replay_button.text = "PLAY LEVEL 3"
		_: replay_button.text = "REPLAY LEVEL %d" % current_level
	level_clear_panel.visible = true
	update_hud()

	# ── Level 3 win — override panel with full-game completion presentation ──────
	if current_level == 3:
		clear_title.text = "FUSE RUN  COMPLETE!"
		clear_summary.text = (
			"Total Score   %d\nBest   %d\n\nAll three levels conquered.\nMore loops coming soon." \
			% [final_score, best_score]
		)
		replay_button.text = "PLAY AGAIN"
		# Gold border on the panel
		_style_panel(level_clear_panel,
			Color(0.05, 0.09, 0.03, 0.97),
			Color(1.00, 0.82, 0.10, 1.0), 4)
		_win_confetti()
		# Dramatic golden flash — longer and brighter than a wave flash
		var wf := ColorRect.new()
		wf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wf.color = Color(1.00, 0.85, 0.10, 0.50)
		wf.size = get_viewport_rect().size
		wf.position = Vector2.ZERO
		wf.modulate = Color(1, 1, 1, 0)
		ui_layer.add_child(wf)
		var wft: Tween = wf.create_tween()
		wft.tween_property(wf, "modulate", Color(1, 1, 1, 1), 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		wft.tween_property(wf, "modulate", Color(1, 1, 1, 0), 1.80) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		wft.tween_callback(wf.queue_free)

func _win_confetti() -> void:
	var vp := get_viewport_rect().size
	var piece_colors: Array[Color] = [
		Color(1.00, 0.82, 0.10, 1.0),   # gold
		Color(0.22, 0.86, 1.00, 1.0),   # cyan
		Color(0.80, 0.35, 1.00, 1.0),   # purple
		Color(0.35, 1.00, 0.50, 1.0),   # green
		Color(1.00, 0.42, 0.18, 1.0),   # orange
		Color(1.00, 1.00, 1.00, 1.0),   # white
	]
	for i in 42:
		var cr := ColorRect.new()
		cr.size = Vector2(randf_range(8.0, 22.0), randf_range(8.0, 22.0))
		cr.color = piece_colors[randi() % piece_colors.size()]
		var sx := randf_range(20.0, vp.x - 20.0)
		var sy := randf_range(vp.y * 0.30, vp.y * 0.95)
		cr.position = Vector2(sx, sy)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cr.modulate.a = 0.0
		ui_layer.add_child(cr)
		var delay := randf_range(0.0, 1.1)
		var end_x := sx + randf_range(-100.0, 100.0)
		var end_y := sy - randf_range(260.0, 580.0)
		var dur := randf_range(1.3, 2.3)
		var t: Tween = cr.create_tween()
		t.set_parallel(true)
		t.tween_property(cr, "modulate:a", 1.0, 0.14).set_delay(delay)
		t.tween_property(cr, "position", Vector2(end_x, end_y), dur) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Delayed fade-out triggered by a timer so it doesn't fight the position tween
		get_tree().create_timer(delay + dur - 0.38).timeout.connect(func():
			if is_instance_valid(cr):
				var fade: Tween = cr.create_tween()
				fade.tween_property(cr, "modulate:a", 0.0, 0.38)
				fade.tween_callback(cr.queue_free)
		)

func _on_music_finished() -> void:
	music_player.play()

func _update_best_score(final_score: int) -> void:
	Global.save_best(current_level, final_score)
	best_score = Global.get_best(current_level)

# ── Hazard speed management ───────────────────────────────────────────────────

func _update_hazard_speed_mult() -> void:
	var mult := 1.0
	if fuse_state_active:
		mult = FUSE_HAZARD_MULT
	if slow_time_active:
		mult = minf(mult, SLOW_TIME_HAZARD_MULT)
	hazard_speed_mult = mult
	for h in get_tree().get_nodes_in_group("hazard"):
		if h.has_method("set_speed_mult"):
			h.set_speed_mult(hazard_speed_mult)
	level1_spawner.hazard_speed_mult = hazard_speed_mult
	level2_spawner.hazard_speed_mult = hazard_speed_mult
	level3_spawner.hazard_speed_mult = hazard_speed_mult

# ── Fuse State ────────────────────────────────────────────────────────────────

func _activate_fuse_state() -> void:
	fuse_state_active = true
	_fuse_timer = FUSE_DURATION
	_update_hazard_speed_mult()
	player.enter_fuse_state()
	fuse_sfx.play()
	_show_fuse_vignette()
	_tint_hazards_fuse(true)
	streak_mult_label.text = "FUSE"
	streak_mult_label.modulate = Color(0.18, 1.0, 0.90, 1.0)
	streak_mult_label.scale = Vector2(1.55, 1.55)
	var tween := streak_mult_label.create_tween()
	tween.tween_property(streak_mult_label, "scale", Vector2.ONE, 0.48) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_show_fuse_banner()

func _deactivate_fuse_state() -> void:
	fuse_state_active = false
	_update_hazard_speed_mult()
	player.exit_fuse_state()
	_hide_fuse_vignette()
	_tint_hazards_fuse(false)
	_animate_streak_collect()

func _update_fuse_countdown() -> void:
	streak_sub_label.text = "FUSE  %.1fs" % _fuse_timer
	streak_sub_label.modulate = Color(1.0, 0.85, 0.30, 0.95)

# ── Slow-time (Purple shard) ──────────────────────────────────────────────────

func _apply_slow_time() -> void:
	if fuse_state_active:
		_fuse_timer += SLOW_TIME_DURATION
	elif slow_time_active:
		_slow_time_timer += SLOW_TIME_DURATION
		_spawn_float_text("EXTENDED!", player.global_position + Vector2(0, -90), 40, Color(0.80, 0.35, 1.00, 1.0))
	else:
		_activate_slow_time()

func _activate_slow_time() -> void:
	slow_time_active = true
	_slow_time_timer = SLOW_TIME_DURATION
	_update_hazard_speed_mult()
	slow_time_sfx.play()
	_spawn_float_text("SLOW TIME!", player.global_position + Vector2(0, -90), 44, Color(0.80, 0.35, 1.00, 1.0))
	_show_pill(_slow_pill)

func _deactivate_slow_time() -> void:
	slow_time_active = false
	_update_hazard_speed_mult()
	slow_time_sfx.stop()
	_hide_pill(_slow_pill)

# ── Jackpot (Gold shard) ──────────────────────────────────────────────────────

func _activate_jackpot(world_pos: Vector2) -> void:
	var refreshed := jackpot_active
	jackpot_active = true
	_jackpot_timer = JACKPOT_DURATION
	jackpot_sfx.play()
	var msg := "JACKPOT  EXT!" if refreshed else "JACKPOT!  ×%d" % JACKPOT_MULT
	_spawn_float_text(msg, world_pos + Vector2(0, -90), 52, Color(1.00, 0.88, 0.15, 1.0))
	_show_pill(_jackpot_pill)

func _deactivate_jackpot() -> void:
	jackpot_active = false
	_hide_pill(_jackpot_pill)

# ── Green shard (heal / shield) ───────────────────────────────────────────────

func _apply_green_effect(world_pos: Vector2) -> void:
	green_sfx.play()
	if player.health < player.max_health:
		player.heal(1)
		_spawn_float_text("+1 HP", world_pos + Vector2(0, -90), 42, Color(0.35, 1.00, 0.50, 1.0))
	else:
		player.grant_shield(2.5)
		_spawn_float_text("SHIELD!", world_pos + Vector2(0, -90), 42, Color(0.35, 1.00, 0.50, 1.0))

# ── Active-effect HUD pills ───────────────────────────────────────────────────

func _build_effect_huds() -> void:
	var vp := get_viewport().get_visible_rect().size
	var x := 16.0
	var y1 := vp.y * 0.36
	var y2 := y1 + PILL_H + 8.0

	var jp := _make_pill(Color(1.00, 0.85, 0.10, 1.0))
	_jackpot_pill       = jp["panel"]
	_jackpot_pill_label = jp["label"]
	_jackpot_pill_bar   = jp["bar"]
	_jackpot_pill.position = Vector2(x, y1)
	ui_layer.add_child(_jackpot_pill)

	var sp := _make_pill(Color(0.78, 0.30, 1.00, 1.0))
	_slow_pill       = sp["panel"]
	_slow_pill_label = sp["label"]
	_slow_pill_bar   = sp["bar"]
	_slow_pill.position = Vector2(x, y2)
	ui_layer.add_child(_slow_pill)

func _make_pill(col: Color) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(PILL_W, PILL_H)
	panel.size = Vector2(PILL_W, PILL_H)
	panel.modulate = Color(1, 1, 1, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.10, 0.88)
	style.border_color = col
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = Vector2(10, 5)
	lbl.size = Vector2(PILL_W - 14, PILL_H - PILL_BAR_H - 5)
	panel.add_child(lbl)

	var bar := ColorRect.new()
	bar.color = col
	bar.position = Vector2(0, PILL_H - PILL_BAR_H)
	bar.size = Vector2(PILL_W, PILL_BAR_H)
	panel.add_child(bar)

	return {"panel": panel, "label": lbl, "bar": bar}

func _show_pill(pill: Panel) -> void:
	if pill == null:
		return
	var t := pill.create_tween()
	t.tween_property(pill, "modulate", Color(1, 1, 1, 1), 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _hide_pill(pill: Panel) -> void:
	if pill == null:
		return
	var t := pill.create_tween()
	t.tween_property(pill, "modulate", Color(1, 1, 1, 0), 0.30) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _update_jackpot_pill() -> void:
	if _jackpot_pill == null:
		return
	var ratio := clampf(_jackpot_timer / JACKPOT_DURATION, 0.0, 1.0)
	_jackpot_pill_label.text = "✦ JACKPOT  ×%d    %.1fs" % [JACKPOT_MULT, maxf(_jackpot_timer, 0.0)]
	_jackpot_pill_bar.size.x = PILL_W * ratio
	var urgent := _jackpot_timer < 2.0
	_jackpot_pill_label.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.08, 1.0) if urgent else Color(1.00, 0.85, 0.10, 1.0))

func _update_slow_pill() -> void:
	if _slow_pill == null:
		return
	var ratio := clampf(_slow_time_timer / SLOW_TIME_DURATION, 0.0, 1.0)
	_slow_pill_label.text = "◈ SLOW TIME    %.1fs" % maxf(_slow_time_timer, 0.0)
	_slow_pill_bar.size.x = PILL_W * ratio
	var urgent := _slow_time_timer < 1.0
	_slow_pill_label.add_theme_color_override("font_color",
		Color(1.0, 0.45, 1.0, 1.0) if urgent else Color(0.78, 0.30, 1.00, 1.0))

# ── Fuse vignette — screen-edge glow + overlay + activation flash ─────────────

func _build_fuse_vignette() -> void:
	var vp := get_viewport().get_visible_rect().size
	const TEAL := Color(0.18, 0.95, 0.85, 0.0)
	const BW   := 60.0   # border thickness in pixels

	# Full-screen teal tint (very subtle, pulses during fuse)
	_fuse_overlay = ColorRect.new()
	_fuse_overlay.color = Color(0.12, 0.88, 0.80, 0.0)
	_fuse_overlay.size = vp
	_fuse_overlay.z_index = -10
	_fuse_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_fuse_overlay)

	# 4 edge borders — top, bottom, left, right
	var rects := [
		Rect2(0,           0,           vp.x, BW  ),
		Rect2(0,           vp.y - BW,   vp.x, BW  ),
		Rect2(0,           0,           BW,   vp.y),
		Rect2(vp.x - BW,  0,           BW,   vp.y),
	]
	for r in rects:
		var cr := ColorRect.new()
		cr.color = TEAL
		cr.position = r.position
		cr.size = r.size
		cr.z_index = -9
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(cr)
		_fuse_borders.append(cr)

func _show_fuse_vignette() -> void:
	# Kill any leftover pulse
	if _fuse_pulse_tween != null and _fuse_pulse_tween.is_valid():
		_fuse_pulse_tween.kill()
		_fuse_pulse_tween = null

	var vp := get_viewport().get_visible_rect().size

	# 1. Bright teal flash — full screen, fades out fast
	var flash := ColorRect.new()
	flash.color = Color(0.35, 1.00, 0.90, 0.60)
	flash.size = vp
	flash.z_index = -8
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "color:a", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ft.tween_callback(flash.queue_free)

	# 2. Fade in ambient overlay
	var ot := _fuse_overlay.create_tween()
	ot.tween_property(_fuse_overlay, "color:a", 0.08, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 3. Fade in edge borders
	for b: ColorRect in _fuse_borders:
		var bt: Tween = b.create_tween()
		bt.tween_property(b, "color:a", 0.55, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 4. Start slow pulse on overlay
	_fuse_pulse_tween = _fuse_overlay.create_tween().set_loops()
	_fuse_pulse_tween.tween_property(_fuse_overlay, "color:a", 0.15, 0.65).set_trans(Tween.TRANS_SINE)
	_fuse_pulse_tween.tween_property(_fuse_overlay, "color:a", 0.04, 0.65).set_trans(Tween.TRANS_SINE)

func _hide_fuse_vignette() -> void:
	if _fuse_pulse_tween != null and _fuse_pulse_tween.is_valid():
		_fuse_pulse_tween.kill()
		_fuse_pulse_tween = null
	# Fade out overlay
	var ot := _fuse_overlay.create_tween()
	ot.tween_property(_fuse_overlay, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Fade out borders
	for b: ColorRect in _fuse_borders:
		var bt: Tween = b.create_tween()
		bt.tween_property(b, "color:a", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _tint_hazards_fuse(active: bool) -> void:
	var target := Color(0.55, 1.00, 0.95, 1.0) if active else Color(1.0, 1.0, 1.0, 1.0)
	for h in get_tree().get_nodes_in_group("hazard"):
		if is_instance_valid(h):
			var ht: Tween = h.create_tween()
			ht.tween_property(h, "modulate", target, 0.30) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _show_fuse_banner() -> void:
	var vp := get_viewport_rect().size

	# ── Character sprite — centred on screen, slams in from scale 0 ──────────
	fuse_character_sprite.position = Vector2(vp.x * 0.5, vp.y * 0.46)
	fuse_character_sprite.scale = Vector2(0.0, 0.0)
	fuse_character_sprite.modulate = Color(1, 1, 1, 1)
	fuse_character_sprite.visible = true
	var char_tween := fuse_character_sprite.create_tween()
	char_tween.tween_property(fuse_character_sprite, "scale", Vector2(0.5, 0.5), 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	char_tween.tween_interval(0.75)
	char_tween.tween_property(fuse_character_sprite, "modulate", Color(1, 1, 1, 0), 0.40) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	char_tween.tween_callback(func(): fuse_character_sprite.visible = false)

	# ── Text banner slides up below the character ─────────────────────────────
	var banner_y_end   := vp.y * 0.562   # ~56% down — same visual ratio on all heights
	var banner_y_start := vp.y * 0.594   # starts just below, slides up
	fuse_banner.size.x = vp.x
	fuse_banner.modulate = Color(1, 1, 1, 0)
	fuse_banner.position = Vector2(0.0, banner_y_start)
	fuse_banner.visible = true
	var tween := fuse_banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fuse_banner, "modulate", Color(1, 1, 1, 1), 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(fuse_banner, "position:y", banner_y_end, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.0)
	tween.chain().tween_property(fuse_banner, "modulate", Color(1, 1, 1, 0), 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): fuse_banner.visible = false)
