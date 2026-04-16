extends Node2D

const LEVEL_BG_PATHS := {
	1: ["res://scenes/background/level 1.PNG", "res://scenes/background/level 1.png"],
	2: ["res://scenes/background/level 2.PNG", "res://scenes/background/level 2.png"],
}

@onready var back_button: Button = $UI/BackButton
@onready var level1_button: TextureButton = $UI/Level1Button
@onready var level1_best: Label = $UI/Level1Best
@onready var level2_button: TextureButton = $UI/Level2Button
@onready var level2_best: Label = $UI/Level2Best
@onready var level2_lock_overlay: ColorRect = $UI/Level2LockOverlay
@onready var level2_lock_label: Label = $UI/Level2LockLabel

func _ready() -> void:
	_load_backgrounds()
	_apply_scores()
	_apply_locks()
	back_button.pressed.connect(_on_back)
	level1_button.pressed.connect(_on_level1)
	level2_button.pressed.connect(_on_level2)

func _load_backgrounds() -> void:
	for level in LEVEL_BG_PATHS:
		var btn: TextureButton = level1_button if level == 1 else level2_button
		for path in LEVEL_BG_PATHS[level]:
			if ResourceLoader.exists(path):
				var tex: Texture2D = load(path)
				if tex:
					btn.texture_normal = tex
					break

func _apply_scores() -> void:
	var b1 := Global.get_best(1)
	var b2 := Global.get_best(2)
	level1_best.text = "Best: %s" % (str(b1) if b1 > 0 else "—")
	level2_best.text = "Best: %s" % (str(b2) if b2 > 0 else "—")

func _apply_locks() -> void:
	var l2_unlocked := Global.is_unlocked(2)
	level2_button.disabled = not l2_unlocked
	level2_lock_overlay.visible = not l2_unlocked
	level2_lock_label.visible = not l2_unlocked
	level2_best.visible = l2_unlocked

func _on_back() -> void:
	Transition.fade_to("res://scenes/menu/Menu.tscn")

func _on_level1() -> void:
	Global.selected_level = 1
	Transition.fade_to("res://scenes/game/Game.tscn")

func _on_level2() -> void:
	if not Global.is_unlocked(2):
		return
	Global.selected_level = 2
	Transition.fade_to("res://scenes/game/Game.tscn")
