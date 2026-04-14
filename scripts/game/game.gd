extends Node2D
class_name Game

enum GameState { START, PLAYING, DEAD, COMPLETE }

const SAVE_PATH := "user://mourk_run.save"

# Fixed: added the actual in-project path first
const LEVEL_1_BG_TEXTURE_PATHS := [
	"res://scenes/background/level 1.PNG",
	"res://assets/art/level1/level1_cave_bg.png",
	"res://assets/art/level1/cave_bg.png",
	"res://assets/art/level1/background.png",
]

@onready var background_fallback: ColorRect = $Background/FallbackBG
@onready var background_art: Sprite2D = $Background/BackgroundArt
@onready var player: Player = $Player
@onready var level1_spawner: Level1Spawner = $Level1Spawner
@onready var hazards_root: Node = $Hazards
@onready var pickups_root: Node = $Pickups

@onready var start_panel: Panel = $UI/StartPanel
@onready var title_label: Label = $UI/StartPanel/TitleLabel
@onready var subtitle_label: Label = $UI/StartPanel/SubtitleLabel
@onready var start_button: Button = $UI/StartPanel/StartButton
@onready var score_label: Label = $UI/ScoreLabel
@onready var best_label: Label = $UI/BestLabel
@onready var wave_label: Label = $UI/WaveLabel
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

func _ready() -> void:
	# Fixed: removed randomize() — deprecated in Godot 4.6
	best_score = load_best_score()
	_setup_background()
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
	restart_button.pressed.connect(start_level_1)
	replay_button.pressed.connect(start_level_1)
	game_over_menu_button.pressed.connect(_show_start_screen)
	clear_menu_button.pressed.connect(_show_start_screen)
	player.hit.connect(_on_player_hit)
	player.mourk_collected.connect(_on_mourk_collected)
	level1_spawner.wave_started.connect(_on_wave_started)
	level1_spawner.wave_cleared.connect(_on_wave_cleared)
	level1_spawner.level_complete.connect(_on_level_complete)

func _setup_ui() -> void:
	title_label.text = "FUSE: MOURK RUN"
	# Fixed: was split across two lines — must be a single string
	subtitle_label.text = "Level 1 — The Mine\nDrag to move • Dodge rocks • Collect mourk shards"
	start_button.text = "START LEVEL 1"
	score_label.text = "Score: 0"
	best_label.text = "Best: %d" % best_score
	wave_label.text = "Wave 1/4"
	score_label.position = Vector2(24, 24)
	wave_label.position = Vector2(285, 24)
	best_label.position = Vector2(540, 24)
	score_label.visible = false
	best_label.visible = false
	wave_label.visible = false
	game_over_panel.visible = false
	score_summary.text = ""
	restart_button.text = "RESTART"
	game_over_menu_button.text = "MENU"
	level_clear_panel.visible = false
	clear_summary.text = ""
	replay_button.text = "REPLAY LEVEL 1"
	clear_menu_button.text = "MENU"

func _setup_background() -> void:
	var viewport_size := get_viewport_rect().size
	background_fallback.color = Color("07151b")
	background_fallback.position = Vector2.ZERO
	background_fallback.size = viewport_size
	background_fallback.visible = true
	background_art.visible = false
	for texture_path in LEVEL_1_BG_TEXTURE_PATHS:
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
	clear_run_objects()
	player.reset_player()
	player.disable_control()
	start_panel.visible = true
	game_over_panel.visible = false
	level_clear_panel.visible = false
	score_label.visible = false
	best_label.visible = false
	wave_label.visible = false
	best_label.text = "Best: %d" % best_score

func start_level_1() -> void:
	state = GameState.PLAYING
	score = 0.0
	current_wave = 1
	total_waves = 4
	clear_run_objects()
	start_panel.visible = false
	game_over_panel.visible = false
	level_clear_panel.visible = false
	score_label.visible = true
	best_label.visible = true
	wave_label.visible = true
	player.reset_player()
	player.enable_control()
	level1_spawner.start_run()
	update_hud()

func update_hud() -> void:
	score_label.text = "Score: %d" % int(floor(score))
	best_label.text = "Best: %d" % best_score
	wave_label.text = "Wave %d/%d" % [current_wave, total_waves]

func clear_run_objects() -> void:
	for child in hazards_root.get_children():
		child.queue_free()
	for child in pickups_root.get_children():
		child.queue_free()

func _on_wave_started(wave: int, total: int) -> void:
	current_wave = wave
	total_waves = total
	update_hud()

func _on_wave_cleared(cleared_wave: int) -> void:
	score += 25.0
	update_hud()

func _on_mourk_collected(points: int) -> void:
	if state != GameState.PLAYING:
		return
	score += points
	update_hud()

func _on_player_hit() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.DEAD
	level1_spawner.stop_run()
	player.disable_control()
	clear_run_objects()
	var final_score := int(floor(score))
	_update_best_score(final_score)
	# Fixed: was split across two lines
	score_summary.text = "You got crushed.\nScore: %d\nBest: %d" % [final_score, best_score]
	game_over_panel.visible = true

func _on_level_complete() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.COMPLETE
	score += 100.0
	level1_spawner.stop_run()
	player.disable_control()
	clear_run_objects()
	var final_score := int(floor(score))
	_update_best_score(final_score)
	# Fixed: was split across two lines
	clear_summary.text = "Level 1 Complete!\nScore: %d\nBest: %d\nLevel 2 coming soon." % [final_score, best_score]
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
