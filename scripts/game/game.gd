extends Node2D
class_name Game

enum GameState { START, PLAYING, DEAD, COMPLETE }

const SAVE_PATH := "user://mourk_run.save"

const LEVEL_1_BG_TEXTURE_PATHS := [
	"res://scenes/background/level 1.PNG",
	"res://assets/art/level1/level1_cave_bg.png",
	"res://assets/art/level1/cave_bg.png",
]

const LEVEL_2_BG_TEXTURE_PATHS := [
	"res://scenes/background/level 2.PNG",
	"res://assets/art/level2/background.png",
]

@onready var background_fallback: ColorRect = $Background/FallbackBG
@onready var background_art: Sprite2D = $Background/BackgroundArt
@onready var player: Player = $Player
@onready var level1_spawner: Level1Spawner = $Level1Spawner
@onready var level2_spawner: Level2Spawner = $Level2Spawner
@onready var hazards_root: Node = $Hazards
@onready var pickups_root: Node = $Pickups

@onready var start_panel: Panel = $UI/StartPanel
@onready var title_label: Label = $UI/StartPanel/TitleLabel
@onready var subtitle_label: Label = $UI/StartPanel/SubtitleLabel
@onready var start_button: Button = $UI/StartPanel/StartButton
@onready var level2_button: Button = $UI/StartPanel/Level2Button
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var health_label: Label = $UI/HealthLabel
@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var score_summary: Label = $UI/GameOverPanel/ScoreSummary
@onready var restart_button: Button = $UI/GameOverPanel/RestartButton
@onready var game_over_menu_button: Button = $UI/GameOverPanel/GameOverMenuButton
@onready var level_clear_panel: Panel = $UI/LevelClearPanel
@onready var clear_summary: Label = $UI/LevelClearPanel/ClearSummary
@onready var replay_button: Button = $UI/LevelClearPanel/ReplayButton
@onready var clear_menu_button: Button = $UI/LevelClearPanel/ClearMenuButton

var state: GameState = GameState.START
var score: float = 0.0
var best_score: int = 0
var current_wave: int = 1
var total_waves: int = 4
var current_level: int = 1

func _ready() -> void:
	best_score = load_best_score()
	_setup_ui()
	_connect_signals()
	_show_start_screen()

func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	score += delta
	update_hud()

func _connect_signals() -> void:
	start_button.pressed.connect(start_level_1)
	level2_button.pressed.connect(start_level_2)
	restart_button.pressed.connect(_restart_current_level)
	replay_button.pressed.connect(_restart_current_level)
	game_over_menu_button.pressed.connect(_show_start_screen)
	clear_menu_button.pressed.connect(_show_start_screen)
	player.hit.connect(_on_player_hit)
	player.mourk_collected.connect(_on_mourk_collected)
	player.health_changed.connect(_on_health_changed)
	level1_spawner.wave_started.connect(_on_wave_started)
	level1_spawner.wave_cleared.connect(_on_wave_cleared)
	level1_spawner.level_complete.connect(_on_level_complete)
	level2_spawner.wave_started.connect(_on_wave_started)
	level2_spawner.wave_cleared.connect(_on_wave_cleared)
	level2_spawner.level_complete.connect(_on_level_complete)

func _setup_ui() -> void:
	title_label.text = "FUSE: MOURK RUN"
	subtitle_label.text = "Drag to move  •  Dodge  •  Collect shards"
	start_button.text = "START LEVEL 1"
	level2_button.text = "PLAY LEVEL 2"
	score_label.text = "Score: 0"
	best_label.text = "Best: %d" % best_score
	wave_label.text = "Wave 1/4"
	health_label.text = ""
	score_label.visible = false
	best_label.visible = false
	wave_label.visible = false
	health_label.visible = false
	game_over_panel.visible = false
	score_summary.text = ""
	restart_button.text = "RESTART"
	game_over_menu_button.text = "MENU"
	level_clear_panel.visible = false
	clear_summary.text = ""
	replay_button.text = "REPLAY"
	clear_menu_button.text = "MENU"

func _setup_background(texture_paths: Array) -> void:
	var viewport_size := get_viewport_rect().size
	background_fallback.color = Color("07151b")
	background_fallback.position = Vector2.ZERO
	background_fallback.size = viewport_size
	background_fallback.visible = true
	background_art.visible = false
	for texture_path in texture_paths:
		if ResourceLoader.exists(texture_path):
			var tex: Texture2D = load(texture_path)
			if tex != null:
				background_art.texture = tex
				background_art.position = viewport_size * 0.5
				var tex_size := tex.get_size()
				var fit_scale := maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
				background_art.scale = Vector2.ONE * fit_scale
				background_art.visible = true
				background_fallback.visible = false
				return

func _show_start_screen() -> void:
	state = GameState.START
	level1_spawner.stop_run()
	level2_spawner.stop_run()
	clear_run_objects()
	player.reset_player()
	player.disable_control()
	start_panel.visible = true
	game_over_panel.visible = false
	level_clear_panel.visible = false
	score_label.visible = false
	best_label.visible = false
	wave_label.visible = false
	health_label.visible = false
	best_label.text = "Best: %d" % best_score
	_setup_background(LEVEL_1_BG_TEXTURE_PATHS)

func _restart_current_level() -> void:
	if current_level == 2:
		start_level_2()
	else:
		start_level_1()

func start_level_1() -> void:
	current_level = 1
	state = GameState.PLAYING
	score = 0.0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(1)
	start_panel.visible = false
	game_over_panel.visible = false
	level_clear_panel.visible = false
	score_label.visible = true
	best_label.visible = true
	wave_label.visible = true
	health_label.visible = false
	_setup_background(LEVEL_1_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	level1_spawner.start_run()
	update_hud()

func start_level_2() -> void:
	current_level = 2
	state = GameState.PLAYING
	score = 0.0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	player.setup(3)
	start_panel.visible = false
	game_over_panel.visible = false
	level_clear_panel.visible = false
	score_label.visible = true
	best_label.visible = true
	wave_label.visible = true
	health_label.visible = true
	_setup_background(LEVEL_2_BG_TEXTURE_PATHS)
	player.reset_player()
	player.enable_control()
	level2_spawner.start_run()
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

func _on_wave_started(wave: int, total: int) -> void:
	current_wave = wave
	total_waves = total
	update_hud()

func _on_wave_cleared(_cleared_wave: int) -> void:
	score += 25.0
	update_hud()

func _on_mourk_collected(points: int) -> void:
	if state != GameState.PLAYING:
		return
	score += points
	update_hud()

func _on_health_changed(new_health: int) -> void:
	_update_health_display(new_health)

func _on_player_hit() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.DEAD
	level1_spawner.stop_run()
	level2_spawner.stop_run()
	player.disable_control()
	clear_run_objects()
	var final_score := int(floor(score))
	_update_best_score(final_score)
	var level_name := "Level %d" % current_level
	score_summary.text = "You got crushed.\n%s  •  Score: %d\nBest: %d" % [level_name, final_score, best_score]
	restart_button.text = "RESTART LEVEL %d" % current_level
	game_over_panel.visible = true

func _on_level_complete() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.COMPLETE
	score += 100.0
	level1_spawner.stop_run()
	level2_spawner.stop_run()
	player.disable_control()
	clear_run_objects()
	var final_score := int(floor(score))
	_update_best_score(final_score)
	var next_level := current_level + 1
	clear_summary.text = "Level %d Complete!\nScore: %d\nBest: %d\nLevel %d coming soon." % [current_level, final_score, best_score, next_level]
	replay_button.text = "REPLAY LEVEL %d" % current_level
	level_clear_panel.visible = true
	update_hud()

func _update_best_score(final_score: int) -> void:
	if final_score > best_score:
		best_score = final_score
		save_best_score(best_score)

func save_best_score(value: int) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(value)

func load_best_score() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		return file.get_32()
	return 0
