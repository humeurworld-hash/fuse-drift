extends Node
class_name MourkSpawner

@export var mourk_scene: PackedScene = preload("res://scenes/pickups/Mourk.tscn")
@export var spawn_interval: float = 1.20
@export var side_padding: float = 60.0

var active := false
var spawn_timer := 0.0

@onready var pickups_root: Node = $"../Pickups"

func start() -> void:
	active = true
	spawn_timer = 0.75

func stop() -> void:
	active = false

func _process(delta: float) -> void:
	if not active or mourk_scene == null:
		return

	spawn_timer -= delta

	if spawn_timer <= 0.0:
		spawn_mourk()
		spawn_timer = randf_range(spawn_interval * 0.75, spawn_interval * 1.25)

func spawn_mourk() -> void:
	var mourk = mourk_scene.instantiate()
	var width := get_viewport().get_visible_rect().size.x

	mourk.position = Vector2(
		randf_range(side_padding, width - side_padding),
		-100.0
	)

	pickups_root.add_child(mourk)
