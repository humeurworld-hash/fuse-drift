extends Node
class_name Level1Spawner

signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(cleared_wave: int)
signal level_complete

@export var rock_scene: PackedScene = preload("res://scenes/hazards/RockHazard.tscn")
@export var shard_scene: PackedScene = preload("res://scenes/pickups/MourkShard.tscn")
@export var side_padding: float = 64.0

const WAVE_DATA := [
	{
		"duration": 22.0,
		"rock_interval": 1.25,
		"shard_interval": 2.30,
		"rock_speed": 340.0,
		"double_chance": 0.00
	},
	{
		"duration": 26.0,
		"rock_interval": 1.00,
		"shard_interval": 2.10,
		"rock_speed": 420.0,
		"double_chance": 0.18
	},
	{
		"duration": 30.0,
		"rock_interval": 0.82,
		"shard_interval": 1.90,
		"rock_speed": 500.0,
		"double_chance": 0.28
	},
	{
		"duration": 35.0,
		"rock_interval": 0.65,
		"shard_interval": 1.70,
		"rock_speed": 590.0,
		"double_chance": 0.40
	}
]

# Seconds of silence between waves — gives the banner time to breathe
const WAVE_GAP := 1.8

@onready var hazards_root: Node = $"../Hazards"
@onready var pickups_root: Node = $"../Pickups"

var active := false
var wave_index := 0
var hazard_speed_mult: float = 1.0
var wave_time := 0.0
var rock_timer := 0.0
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

	# Between-wave silence
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
	rock_timer -= delta
	shard_timer -= delta

	if rock_timer <= 0.0:
		_spawn_rock(cfg)
		rock_timer = randf_range(float(cfg["rock_interval"]) * 0.85, float(cfg["rock_interval"]) * 1.15)

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
	rock_timer = float(cfg["rock_interval"]) * 0.75
	shard_timer = float(cfg["shard_interval"]) * 0.90

func _spawn_rock(cfg: Dictionary) -> void:
	if rock_scene == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var rock: RockHazard = rock_scene.instantiate()
	rock.position = Vector2(randf_range(side_padding, width - side_padding), -120.0)
	rock.speed = float(cfg["rock_speed"]) + randf_range(-30.0, 60.0)
	hazards_root.add_child(rock)
	rock.speed_mult = hazard_speed_mult

	if randf() < float(cfg["double_chance"]):
		var rock2: RockHazard = rock_scene.instantiate()
		var offset_dir := -1.0 if randf() < 0.5 else 1.0
		var second_x := clampf(rock.position.x + randf_range(110.0, 180.0) * offset_dir, side_padding, width - side_padding)
		rock2.position = Vector2(second_x, -160.0)
		rock2.speed = float(cfg["rock_speed"]) + randf_range(10.0, 85.0)
		hazards_root.add_child(rock2)
		rock2.speed_mult = hazard_speed_mult

# Colors available per wave (escalates from common → rare as waves progress)
const WAVE_SHARD_COLORS := [
	[MourkShard.ShardColor.TEAL],                                       # wave 1
	[MourkShard.ShardColor.TEAL,   MourkShard.ShardColor.GREEN],        # wave 2
	[MourkShard.ShardColor.GREEN,  MourkShard.ShardColor.ORANGE],       # wave 3
	[MourkShard.ShardColor.ORANGE, MourkShard.ShardColor.PURPLE],       # wave 4
]

func _spawn_shard(cfg: Dictionary) -> void:
	if shard_scene == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var shard: MourkShard = shard_scene.instantiate()
	var palette: Array = WAVE_SHARD_COLORS[wave_index]
	shard.set_color(palette[randi() % palette.size()])
	shard.position = Vector2(randf_range(side_padding, width - side_padding), -96.0)
	shard.speed = maxf(250.0, float(cfg["rock_speed"]) - 110.0)
	pickups_root.add_child(shard)
