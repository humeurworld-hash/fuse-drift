extends Node
class_name Level2Spawner

signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(cleared_wave: int)
signal level_complete

@export var drone1_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/CanvasDrone1.tscn")
@export var drone2_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/CanvasDrone2.tscn")
@export var drone3_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/CanvasDrone3.tscn")
@export var shard_scene: PackedScene = preload("res://scenes/pickups/MourkShard.tscn")
@export var side_padding: float = 72.0

const WAVE_DATA := [
	{
		"duration": 25.0,
		"interval": 2.2,
		"shard_interval": 2.8,
		"speed": 260.0,
		"tiers": [1, 1, 1]
	},
	{
		"duration": 29.0,
		"interval": 1.8,
		"shard_interval": 2.4,
		"speed": 310.0,
		"tiers": [1, 1, 2]
	},
	{
		"duration": 33.0,
		"interval": 1.4,
		"shard_interval": 2.0,
		"speed": 360.0,
		"tiers": [1, 2, 2]
	},
	{
		"duration": 38.0,
		"interval": 1.1,
		"shard_interval": 1.8,
		"speed": 420.0,
		"tiers": [1, 2, 3]
	}
]

const WAVE_GAP := 1.8

@onready var hazards_root: Node = $"../Hazards"
@onready var pickups_root: Node = $"../Pickups"

var active := false
var wave_index := 0
var wave_time := 0.0
var drone_timer := 0.0
var shard_timer := 0.0

var _in_gap := false
var _gap_timer := 0.0
var _next_wave_index := 0

func start_run() -> void:
	active = true
	wave_index = 0
	wave_time = 0.0
	_in_gap = false
	_gap_timer = 0.0
	_reset_timers_for_current_wave()
	wave_started.emit(1, WAVE_DATA.size())

func stop_run() -> void:
	active = false
	_in_gap = false

func _process(delta: float) -> void:
	if not active:
		return

	if _in_gap:
		_gap_timer -= delta
		if _gap_timer <= 0.0:
			_in_gap = false
			wave_index = _next_wave_index
			wave_time = 0.0
			_reset_timers_for_current_wave()
			wave_started.emit(wave_index + 1, WAVE_DATA.size())
		return

	var cfg: Dictionary = WAVE_DATA[wave_index]
	wave_time += delta
	drone_timer -= delta
	shard_timer -= delta

	if drone_timer <= 0.0:
		_spawn_drone(cfg)
		drone_timer = randf_range(float(cfg["interval"]) * 0.8, float(cfg["interval"]) * 1.2)

	if shard_timer <= 0.0:
		_spawn_shard(cfg)
		shard_timer = randf_range(float(cfg["shard_interval"]) * 0.85, float(cfg["shard_interval"]) * 1.15)

	if wave_time >= float(cfg["duration"]):
		wave_cleared.emit(wave_index + 1)
		if wave_index >= WAVE_DATA.size() - 1:
			active = false
			level_complete.emit()
		else:
			_in_gap = true
			_gap_timer = WAVE_GAP
			_next_wave_index = wave_index + 1

func _reset_timers_for_current_wave() -> void:
	var cfg: Dictionary = WAVE_DATA[wave_index]
	drone_timer = float(cfg["interval"]) * 0.6
	shard_timer = float(cfg["shard_interval"]) * 0.9

func _spawn_drone(cfg: Dictionary) -> void:
	var width := get_viewport().get_visible_rect().size.x
	var tiers: Array = cfg["tiers"]
	var tier: int = tiers[randi() % tiers.size()]

	var scene: PackedScene
	match tier:
		1: scene = drone1_scene
		2: scene = drone2_scene
		3: scene = drone3_scene
		_: scene = drone1_scene

	if scene == null:
		return

	var drone: CanvasDrone = scene.instantiate()
	drone.speed = float(cfg["speed"]) + randf_range(-20.0, 40.0)
	drone.position = Vector2(randf_range(side_padding, width - side_padding), -140.0)
	hazards_root.add_child(drone)

func _spawn_shard(cfg: Dictionary) -> void:
	if shard_scene == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var shard: MourkShard = shard_scene.instantiate()
	shard.position = Vector2(randf_range(side_padding, width - side_padding), -96.0)
	shard.speed = maxf(220.0, float(cfg["speed"]) - 120.0)
	pickups_root.add_child(shard)
