extends Node2D

const BG_PATHS := [
	"res://scenes/menu/menu_bg.PNG",
	"res://scenes/menu/menu_bg.png",
]

@onready var fallback_bg: ColorRect = $FallbackBG
@onready var background_art: Sprite2D = $BackgroundArt
@onready var best_score_label: Label = $UI/BestScoreLabel
@onready var run_button: TextureButton = $UI/RunButton
@onready var levels_button: Button = $UI/LevelsButton

func _ready() -> void:
	_setup_background()
	_load_scores()
	run_button.pressed.connect(_on_run)
	levels_button.pressed.connect(_on_levels)

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
	var overall := Global.get_overall_best()
	best_score_label.text = "BEST: %s" % (str(overall) if overall > 0 else "—")

func _on_run() -> void:
	Global.selected_level = 1
	Transition.fade_to("res://scenes/game/Game.tscn")

func _on_levels() -> void:
	Transition.fade_to("res://scenes/levels/LevelSelect.tscn")
