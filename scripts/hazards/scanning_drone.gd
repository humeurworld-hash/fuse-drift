extends Area2D
class_name ScanningDrone

@export var speed: float = 180.0
@export var damage: int = 1

var speed_mult: float = 1.0

enum Phase { DESCEND, SCAN, FIRE, RESUME }
var _phase: Phase = Phase.DESCEND
var _phase_timer: float = 0.0
var _target_x: float = 0.0

var _aim_line: Line2D = null
var _fire_poly: Polygon2D = null

const SCAN_TRIGGER_RATIO := 0.32   # % of screen height where scanning begins
const SCAN_DURATION      := 1.4   # seconds the aim beam tracks the player
const FIRE_DURATION      := 0.38  # seconds the fire beam is visible
const BEAM_WIDTH         := 72.0  # width of the fire column

func set_speed_mult(mult: float) -> void:
	speed_mult = mult

func _ready() -> void:
	add_to_group("hazard")
	add_to_group("drone")

func _process(delta: float) -> void:
	var vp_h := get_viewport().get_visible_rect().size.y

	match _phase:
		Phase.DESCEND:
			position.y += speed * speed_mult * delta
			if position.y >= vp_h * SCAN_TRIGGER_RATIO:
				_begin_scan(vp_h)

		Phase.SCAN:
			_phase_timer -= delta
			_track_player()
			_update_aim_line(vp_h)
			if _phase_timer <= 0.0:
				_begin_fire(vp_h)

		Phase.FIRE:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_end_fire()

		Phase.RESUME:
			position.y += speed * speed_mult * delta

	if position.y > vp_h + 200.0:
		_cleanup()
		queue_free()

func _track_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		_target_x = players[0].position.x

func _begin_scan(vp_h: float) -> void:
	_phase = Phase.SCAN
	_phase_timer = SCAN_DURATION
	_track_player()
	_aim_line = Line2D.new()
	_aim_line.width = 3.0
	_aim_line.default_color = Color(1.0, 0.18, 0.18, 0.55)
	get_parent().add_child(_aim_line)
	_update_aim_line(vp_h)

func _update_aim_line(vp_h: float) -> void:
	if not is_instance_valid(_aim_line):
		return
	_aim_line.clear_points()
	_aim_line.add_point(Vector2(_target_x, position.y + 50.0))
	_aim_line.add_point(Vector2(_target_x, vp_h))

func _begin_fire(vp_h: float) -> void:
	_phase = Phase.FIRE
	_phase_timer = FIRE_DURATION
	if is_instance_valid(_aim_line):
		_aim_line.queue_free()
		_aim_line = null
	# Full-height fire column at the locked X
	var hw := BEAM_WIDTH * 0.5
	_fire_poly = Polygon2D.new()
	_fire_poly.color = Color(1.0, 0.12, 0.12, 0.68)
	_fire_poly.polygon = PackedVector2Array([
		Vector2(_target_x - hw, 0.0),
		Vector2(_target_x + hw, 0.0),
		Vector2(_target_x + hw, vp_h),
		Vector2(_target_x - hw, vp_h),
	])
	get_parent().add_child(_fire_poly)
	# Check if player is inside the beam right now
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.get("invincible") and p.get("alive"):
			if abs(p.position.x - _target_x) <= hw + 14.0:
				if p.has_method("take_hit"):
					p.take_hit(damage)

func _end_fire() -> void:
	if is_instance_valid(_fire_poly):
		var tween := _fire_poly.create_tween()
		tween.tween_property(_fire_poly, "modulate:a", 0.0, 0.20)
		tween.tween_callback(_fire_poly.queue_free)
		_fire_poly = null
	_phase = Phase.RESUME

func _cleanup() -> void:
	if is_instance_valid(_aim_line):
		_aim_line.queue_free()
	if is_instance_valid(_fire_poly):
		_fire_poly.queue_free()

func flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.05)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
