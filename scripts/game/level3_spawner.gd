extends Node
class_name Level3Spawner

signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(cleared_wave: int)
signal level_complete

@export var clock1_scene: PackedScene = preload("res://scenes/hazards/level 3 hazards/Clock1.tscn")
@export var clock2_scene: PackedScene = preload("res://scenes/hazards/level 3 hazards/Clock2.tscn")
@export var clock3_scene: PackedScene = preload("res://scenes/hazards/level 3 hazards/Clock3.tscn")
@export var shard_scene: PackedScene = preload("res://scenes/pickups/MourkShard.tscn")
@export var side_padding: float = 72.0

# Tiers weighted pool per wave — clock3 is the rewinder, used sparingly early, more in later waves
const WAVE_DATA := [
	{
		"duration": 16.0,
		"interval": 2.0,
		"shard_interval": 2.6,
		"speed": 280.0,
		"tiers": [1, 1, 1, 2]
	},
	{
		"duration": 18.0,
		"interval": 1.6,
		"shard_interval": 2.2,
		"speed": 340.0,
		"tiers": [1, 1, 2, 2]
	},
	{
		"duration": 20.0,
		"interval": 1.2,
		"shard_interval": 1.8,
		"speed": 410.0,
		"tiers": [1, 2, 2, 3]
	},
	{
		"duration": 22.0,
		"interval": 1.0,
		"shard_interval": 1.6,
		"speed": 480.0,
		"tiers": [1, 2, 3, 3, 3]
	}
]

@onready var hazards_root: Node = $"../Hazards"
@onready var pickups_root: Node = $"../Pickups"

var active := false
var wave_index := 0
var wave_time := 0.0
var clock_timer := 0.0
var shard_timer := 0.0

func start_run() -> void:
	active = true
	wave_index = 0
	wave_time = 0.0
	_reset_timers()
	wave_started.emit(1, WAVE_DATA.size())

func stop_run() -> void:
	active = false

func _process(delta: float) -> void:
	if not active:
		return

	var cfg: Dictionary = WAVE_DATA[wave_index]
	wave_time += delta
	clock_timer -= delta
	shard_timer -= delta

	if clock_timer <= 0.0:
		_spawn_clock(cfg)
		clock_timer = randf_range(float(cfg["interval"]) * 0.8, float(cfg["interval"]) * 1.2)

	if shard_timer <= 0.0:
		_spawn_shard(cfg)
		shard_timer = randf_range(float(cfg["shard_interval"]) * 0.85, float(cfg["shard_interval"]) * 1.15)

	if wave_time >= float(cfg["duration"]):
		wave_cleared.emit(wave_index + 1)
		if wave_index >= WAVE_DATA.size() - 1:
			active = false
			level_complete.emit()
		else:
			wave_index += 1
			wave_time = 0.0
			_reset_timers()
			wave_started.emit(wave_index + 1, WAVE_DATA.size())

func _reset_timers() -> void:
	var cfg: Dictionary = WAVE_DATA[wave_index]
	clock_timer = float(cfg["interval"]) * 0.7
	shard_timer = float(cfg["shard_interval"]) * 0.9

func _spawn_clock(cfg: Dictionary) -> void:
	var width := get_viewport().get_visible_rect().size.x
	var tiers: Array = cfg["tiers"]
	var tier: int = tiers[randi() % tiers.size()]

	var scene: PackedScene
	match tier:
		1: scene = clock1_scene
		2: scene = clock2_scene
		3: scene = clock3_scene
		_: scene = clock1_scene

	if scene == null:
		return

	var clock: ClockHazard = scene.instantiate()
	clock.speed = float(cfg["speed"]) + randf_range(-20.0, 40.0)
	clock.position = Vector2(randf_range(side_padding, width - side_padding), -150.0)
	hazards_root.add_child(clock)

func _spawn_shard(cfg: Dictionary) -> void:
	if shard_scene == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var shard: MourkShard = shard_scene.instantiate()
	shard.position = Vector2(randf_range(side_padding, width - side_padding), -96.0)
	shard.speed = maxf(200.0, float(cfg["speed"]) - 140.0)
	pickups_root.add_child(shard)
