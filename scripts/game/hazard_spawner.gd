extends Node
class_name HazardSpawner

@export var hazard_scene_1: PackedScene = preload("res://scenes/hazards/CanvasDrone1.tscn")
@export var hazard_scene_2: PackedScene = preload("res://scenes/hazards/CanvasDrone2.tscn")
@export var hazard_scene_3: PackedScene = preload("res://scenes/hazards/CanvasDrone3.tscn")
@export var base_interval: float = 0.90
@export var min_interval: float = 0.32
@export var speedup_per_second: float = 0.006
@export var side_padding: float = 60.0

# Tier thresholds (seconds)
const TIER2_TIME := 20.0
const TIER3_TIME := 45.0

var active := false
var elapsed := 0.0
var spawn_timer := 0.0

@onready var hazards_root: Node = $"../Hazards"

func start() -> void:
	active = true
	elapsed = 0.0
	spawn_timer = 0.25

func stop() -> void:
	active = false

func _process(delta: float) -> void:
	if not active:
		return

	elapsed += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		spawn_hazard()
		var interval := maxf(min_interval, base_interval - (elapsed * speedup_per_second))
		spawn_timer = randf_range(interval * 0.8, interval * 1.2)

func _pick_scene() -> PackedScene:
	if elapsed >= TIER3_TIME:
		# All three, weighted toward harder ones
		var roll := randf()
		if roll < 0.25:
			return hazard_scene_1
		elif roll < 0.55:
			return hazard_scene_2
		else:
			return hazard_scene_3
	elif elapsed >= TIER2_TIME:
		# Level 1 and 2 only
		return hazard_scene_1 if randf() < 0.5 else hazard_scene_2
	else:
		return hazard_scene_1

func spawn_hazard() -> void:
	var scene := _pick_scene()
	if scene == null:
		return

	var hazard = scene.instantiate()
	var width := get_viewport().get_visible_rect().size.x

	hazard.position = Vector2(
		randf_range(side_padding, width - side_padding),
		-120.0
	)
	hazard.speed = 420.0 + minf(elapsed * 12.0, 280.0)
	hazards_root.add_child(hazard)
