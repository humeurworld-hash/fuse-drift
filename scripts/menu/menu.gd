extends Node2D

const BG_PATHS := [
	"res://scenes/menu/menu_bg.PNG",
	"res://scenes/menu/menu_bg.png",
]

const SAVE_PATH := "user://mourk_run.save"

@onready var fallback_bg: ColorRect = $FallbackBG
@onready var background_art: Sprite2D = $BackgroundArt
@onready var best_score_label: Label = $UI/BestScoreLabel
@onready var run_button: TextureButton = $UI/RunButton
@onready var choose_level_button: Button = $UI/ChooseLevelButton
@onready var choose_panel: Panel = $UI/ChooseLevelPanel
@onready var level1_button: Button = $UI/ChooseLevelPanel/Level1Button
@onready var level1_best: Label = $UI/ChooseLevelPanel/Level1BestLabel
@onready var level2_button: Button = $UI/ChooseLevelPanel/Level2Button
@onready var level2_best: Label = $UI/ChooseLevelPanel/Level2BestLabel
@onready var back_button: Button = $UI/ChooseLevelPanel/BackButton

func _ready() -> void:
	_setup_background()
	_load_scores()
	choose_panel.visible = false
	run_button.pressed.connect(_on_run)
	choose_level_button.pressed.connect(_on_choose_level)
	level1_button.pressed.connect(_on_level1)
	level2_button.pressed.connect(_on_level2)
	back_button.pressed.connect(_on_back)

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

func _load_scores() -> void:
	var best := 0
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			best = file.get_32()
	var best_str := str(best) if best > 0 else "—"
	best_score_label.text = "BEST: %s" % best_str
	level1_best.text = "Best: %s" % best_str
	level2_best.text = "Best: %s" % best_str

func _on_run() -> void:
	Global.selected_level = 1
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_choose_level() -> void:
	run_button.visible = false
	choose_level_button.visible = false
	choose_panel.visible = true

func _on_level1() -> void:
	Global.selected_level = 1
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_level2() -> void:
	Global.selected_level = 2
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_back() -> void:
	choose_panel.visible = false
	run_button.visible = true
	choose_level_button.visible = true
