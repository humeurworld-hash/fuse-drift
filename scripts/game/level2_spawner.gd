extends Node
class_name Level2Spawner

signal wave_started(current_wave: int, total_waves: int)
signal wave_cleared(cleared_wave: int)
signal level_complete

@export var drone1_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/CanvasDrone1.tscn")
@export var drone2_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/CanvasDrone2.tscn")
@export var drone3_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/CanvasDrone3.tscn")
@export var drone4_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/CanvasDrone4.tscn")
@export var scanning_drone_scene: PackedScene = preload("res://scenes/hazards/level 2 hazards/ScanningDrone.tscn")
@export var shard_scene: PackedScene = preload("res://scenes/pickups/MourkShard.tscn")
@export var side_padding: float = 72.0

# palette weights sum to 100 for readability — level 2 starts mid-tier
const WAVE_DATA := [
	{
		"duration": 25.0,
		"interval": 2.2,
		"speed": 260.0,
		"tiers": [1, 1, 1],
		"shard_interval": 2.80,
		"palette": {
			MourkShard.ShardColor.TEAL:   73,
			MourkShard.ShardColor.GREEN:   3,
			MourkShard.ShardColor.ORANGE: 19,
			MourkShard.ShardColor.PURPLE:  5,
		}
	},
	{
		"duration": 29.0,
		"interval": 1.8,
		"speed": 310.0,
		"tiers": [1, 1, 2],
		"shard_interval": 2.40,
		"palette": {
			MourkShard.ShardColor.TEAL:   62,
			MourkShard.ShardColor.GREEN:   2,
			MourkShard.ShardColor.ORANGE: 24,
			MourkShard.ShardColor.PURPLE: 10,
			MourkShard.ShardColor.GOLD:    2,
		}
	},
	{
		"duration": 33.0,
		"interval": 1.4,
		"speed": 360.0,
		"tiers": [1, 2, 3],
		"scan_interval": 14.0,
		"shard_interval": 2.00,
		"palette": {
			MourkShard.ShardColor.TEAL:   52,
			MourkShard.ShardColor.GREEN:   2,
			MourkShard.ShardColor.ORANGE: 26,
			MourkShard.ShardColor.PURPLE: 15,
			MourkShard.ShardColor.GOLD:    5,
		}
	},
	{
		"duration": 38.0,
		"interval": 1.1,
		"speed": 420.0,
		"tiers": [2, 3, 4],
		"scan_interval": 10.0,
		"shard_interval": 1.70,
		"palette": {
			MourkShard.ShardColor.TEAL:   42,
			MourkShard.ShardColor.GREEN:   2,
			MourkShard.ShardColor.ORANGE: 28,
			MourkShard.ShardColor.PURPLE: 18,
			MourkShard.ShardColor.GOLD:   10,
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
var drone_timer := 0.0
var shard_timer := 0.0
var scan_timer := 999.0

var _in_gap := false
var _gap_timer := 0.0
var _next_wave_index := 0
var _start_delay: float = 0.0   # grace period before first drone spawns

func start_run() -> void:
	active = true
	wave_index = 0
	wave_time = 0.0
	_in_gap = false
	_gap_timer = 0.0
	_start_delay = 1.5            # give player a moment to orient
	_reset_timers_for_current_wave()
	wave_started.emit(1, WAVE_DATA.size())

func stop_run() -> void:
	active = false
	_in_gap = false
	_start_delay = 0.0

func _process(delta: float) -> void:
	if not active:
		return

	if _start_delay > 0.0:
		_start_delay -= delta
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

	if cfg.has("scan_interval"):
		scan_timer -= delta
		if scan_timer <= 0.0:
			_spawn_scanning_drone()
			scan_timer = randf_range(float(cfg["scan_interval"]) * 0.85, float(cfg["scan_interval"]) * 1.15)

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
	shard_timer = float(cfg["shard_interval"]) * 0.90
	if cfg.has("scan_interval"):
		scan_timer = float(cfg["scan_interval"]) * 0.6
	else:
		scan_timer = 999.0

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

func _spawn_drone(cfg: Dictionary) -> void:
	var width := get_viewport().get_visible_rect().size.x
	var tiers: Array = cfg["tiers"]
	var tier: int = tiers[randi() % tiers.size()]

	var scene: PackedScene
	match tier:
		1: scene = drone1_scene
		2: scene = drone2_scene
		3: scene = drone3_scene
		4: scene = drone4_scene
		_: scene = drone1_scene

	if scene == null:
		return

	var diff_mult := Global.DIFFICULTY_SPEED_MULT[clampi(Global.difficulty, 0, 2)]
	var drone: CanvasDrone = scene.instantiate()
	drone.speed = (float(cfg["speed"]) + randf_range(-20.0, 40.0)) * diff_mult
	drone.position = Vector2(randf_range(side_padding, width - side_padding), -140.0)
	hazards_root.add_child(drone)
	drone.speed_mult = hazard_speed_mult

func _spawn_scanning_drone() -> void:
	if scanning_drone_scene == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var drone: ScanningDrone = scanning_drone_scene.instantiate()
	drone.position = Vector2(randf_range(side_padding, width - side_padding), -150.0)
	drone.speed = 170.0 + randf_range(-20.0, 20.0)
	hazards_root.add_child(drone)
	drone.speed_mult = hazard_speed_mult

func _spawn_shard(cfg: Dictionary) -> void:
	if shard_scene == null:
		return
	var width := get_viewport().get_visible_rect().size.x
	var shard: MourkShard = shard_scene.instantiate()
	shard.set_color(_pick_weighted_color(cfg["palette"]))
	shard.position = Vector2(randf_range(side_padding, width - side_padding), -96.0)
	shard.speed = 230.0 + randf_range(-15.0, 25.0)
	pickups_root.add_child(shard)
