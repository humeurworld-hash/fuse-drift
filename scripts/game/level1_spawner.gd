extends Node
class_name Level1Spawner

signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(cleared_wave: int)
signal level_complete

@export var rock_scene: PackedScene = preload("res://scenes/hazards/RockHazard.tscn")
@export var shard_scene: PackedScene = preload("res://scenes/pickups/MourkShard.tscn")
@export var side_padding: float = 64.0

# palette weights sum to 100 for readability — higher = more common
const WAVE_DATA := [
	{
		"duration": 22.0,
		"rock_interval": 1.25,
		"rock_speed": 340.0,
		"double_chance": 0.00,
		"shard_interval": 2.60,
		"palette": {
			MourkShard.ShardColor.TEAL:   91,
			MourkShard.ShardColor.GREEN:   3,
			MourkShard.ShardColor.ORANGE:  6,
		}
	},
	{
		"duration": 26.0,
		"rock_interval": 1.00,
		"rock_speed": 420.0,
		"double_chance": 0.18,
		"shard_interval": 2.20,
		"palette": {
			MourkShard.ShardColor.TEAL:   83,
			MourkShard.ShardColor.GREEN:   3,
			MourkShard.ShardColor.ORANGE: 11,
			MourkShard.ShardColor.PURPLE:  3,
		}
	},
	{
		"duration": 30.0,
		"rock_interval": 0.82,
		"rock_speed": 500.0,
		"double_chance": 0.28,
		"shard_interval": 1.90,
		"palette": {
			MourkShard.ShardColor.TEAL:   75,
			MourkShard.ShardColor.GREEN:   3,
			MourkShard.ShardColor.ORANGE: 17,
			MourkShard.ShardColor.PURPLE:  5,
		}
	},
	{
		"duration": 35.0,
		"rock_interval": 0.65,
		"rock_speed": 590.0,
		"double_chance": 0.40,
		"shard_interval": 1.65,
		"palette": {
			MourkShard.ShardColor.TEAL:   66,
			MourkShard.ShardColor.GREEN:   2,
			MourkShard.ShardColor.ORANGE: 22,
			MourkShard.ShardColor.PURPLE:  7,
			MourkShard.ShardColor.GOLD:    3,
		}
	}
]

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

func _pick_weighted_color(palette: Dictionary) -> MourkShard.ShardColor:
	var total := 0
	for w in palette.values():
		total += int(w)
	var roll := randi() % total
	var accum := 0
	for color in palette.keys():
		accum += int(palette[color])
		if roll < accum:
			return color as MourkShard.ShardColor
	return MourkShard.ShardColor.TEAL

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

func _spawn_shard(cfg: Dictionary) -> void:
	if shard_scene == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var shard: MourkShard = shard_scene.instantiate()
	shard.set_color(_pick_weighted_color(cfg["palette"]))
	shard.position = Vector2(randf_range(side_padding, width - side_padding), -96.0)
	shard.speed = 230.0 + randf_range(-15.0, 25.0)
	pickups_root.add_child(shard)
