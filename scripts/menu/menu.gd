extends Node2D

const BG_PATHS := [
	"res://scenes/menu/Menu Background.PNG",
	"res://scenes/menu/Landing Page.PNG",
	"res://scenes/menu/menu_bg.PNG",
	"res://scenes/menu/menu_bg.png",
]

const LEVEL_NAMES := {
	1: "Level 1 — The Surface",
	2: "Level 2 — The Canvas",
	3: "Level 3 — The Loops",
}

@onready var fallback_bg: ColorRect = $FallbackBG
@onready var background_art: Sprite2D = $BackgroundArt
@onready var best_score_label: Label = $UI/BestScoreLabel
@onready var continue_button: TextureButton = $UI/ContinueButton
@onready var continue_level_label: Label = $UI/ContinueLevelLabel
@onready var run_button: TextureButton = $UI/RunButton
@onready var levels_button: TextureButton = $UI/LevelsButton
@onready var settings_button: TextureButton = $UI/SettingsButton

var _continue_level: int = 1

func _ready() -> void:
	_setup_background()
	_load_scores()
	_setup_continue()
	continue_button.pressed.connect(_on_continue)
	run_button.pressed.connect(_on_run)
	levels_button.pressed.connect(_on_levels)
	settings_button.pressed.connect(_on_settings)

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

func _setup_continue() -> void:
	# Find the highest unlocked level that has been played (has a best score),
	# or simply the highest unlocked level if they haven't played it yet.
	var highest_unlocked := 1
	for lvl in [3, 2]:
		if Global.is_unlocked(lvl):
			highest_unlocked = lvl
			break

	# Only show Continue if something beyond Level 1 is accessible
	if highest_unlocked <= 1:
		continue_button.visible = false
		continue_level_label.visible = false
		return

	_continue_level = highest_unlocked
	continue_button.visible = true
	continue_level_label.visible = true
	continue_level_label.text = LEVEL_NAMES.get(highest_unlocked, "")

func _on_continue() -> void:
	Global.selected_level = _continue_level
	Transition.fade_to("res://scenes/game/Game.tscn")

func _on_run() -> void:
	Global.selected_level = 1
	Transition.fade_to("res://scenes/game/Game.tscn")

func _on_levels() -> void:
	Transition.fade_to("res://scenes/levels/LevelSelect.tscn")

func _on_settings() -> void:
	pass  # placeholder — settings page not yet built
