extends Node2D

const LEVEL_BG_PATHS := {
	1: ["res://scenes/background/new level 1.png", "res://scenes/background/level 1.PNG", "res://scenes/background/level 1.png"],
	2: ["res://scenes/background/new level 2.png", "res://scenes/background/level 2.PNG", "res://scenes/background/level 2.png"],
	3: ["res://scenes/background/new level 3.png", "res://scenes/background/level 3.PNG", "res://scenes/background/level 3.png"],
}

@onready var back_button: Button = $UI/BackButton
@onready var level1_button: TextureButton = $UI/Level1Button
@onready var level1_best: Label = $UI/Level1Best
@onready var level2_button: TextureButton = $UI/Level2Button
@onready var level2_best: Label = $UI/Level2Best
@onready var level2_lock_overlay: ColorRect = $UI/Level2LockOverlay
@onready var level2_lock_label: Label = $UI/Level2LockLabel
@onready var level3_button: TextureButton = $UI/Level3Button
@onready var level3_best: Label = $UI/Level3Best
@onready var level3_lock_overlay: ColorRect = $UI/Level3LockOverlay
@onready var level3_lock_label: Label = $UI/Level3LockLabel

func _ready() -> void:
	_load_backgrounds()
	_apply_scores()
	_apply_locks()
	back_button.pressed.connect(_on_back)
	level1_button.pressed.connect(_on_level1)
	level2_button.pressed.connect(_on_level2)
	level3_button.pressed.connect(_on_level3)

func _load_backgrounds() -> void:
	var buttons := { 1: level1_button, 2: level2_button, 3: level3_button }
	for level in LEVEL_BG_PATHS:
		var btn: TextureButton = buttons[level]
		for path in LEVEL_BG_PATHS[level]:
			if ResourceLoader.exists(path):
				var tex: Texture2D = load(path)
				if tex:
					btn.texture_normal = tex
					break

func _apply_scores() -> void:
	var b1 := Global.get_best(1)
	var b2 := Global.get_best(2)
	var b3 := Global.get_best(3)
	level1_best.text = "Best: %s" % (str(b1) if b1 > 0 else "—")
	level2_best.text = "Best: %s" % (str(b2) if b2 > 0 else "—")
	level3_best.text = "Best: %s" % (str(b3) if b3 > 0 else "—")

func _apply_locks() -> void:
	var l2_unlocked := Global.is_unlocked(2)
	level2_button.disabled = not l2_unlocked
	level2_lock_overlay.visible = not l2_unlocked
	level2_lock_label.visible = not l2_unlocked
	level2_best.visible = l2_unlocked

	var l3_unlocked := Global.is_unlocked(3)
	level3_button.disabled = not l3_unlocked
	level3_lock_overlay.visible = not l3_unlocked
	level3_lock_label.visible = not l3_unlocked
	level3_best.visible = l3_unlocked

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

func _on_level3() -> void:
	if not Global.is_unlocked(3):
		return
	Global.selected_level = 3
	Transition.fade_to("res://scenes/game/Game.tscn")
