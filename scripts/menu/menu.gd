extends Node2D

# Drop your menu background image at:
#   res://scenes/menu/menu_bg.PNG
# It will load automatically.

const BG_PATHS := [
	"res://scenes/menu/menu_bg.PNG",
	"res://scenes/menu/menu_bg.png",
]

@onready var fallback_bg: ColorRect = $FallbackBG
@onready var background_art: Sprite2D = $BackgroundArt
@onready var run_button: Button = $UI/RunButton
@onready var choose_level_button: Button = $UI/ChooseLevelButton
@onready var choose_panel: Panel = $UI/ChooseLevelPanel
@onready var level1_button: Button = $UI/ChooseLevelPanel/Level1Button
@onready var level2_button: Button = $UI/ChooseLevelPanel/Level2Button
@onready var back_button: Button = $UI/ChooseLevelPanel/BackButton

func _ready() -> void:
	_setup_background()
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
