extends Area2D
class_name ClockHazard

@export var tier: int = 1
@export var speed: float = 300.0
@export var damage: int = 1
@export var is_rewinder: bool = false

var _time: float = 0.0
var _start_x: float = 0.0

func _ready() -> void:
	add_to_group("hazard")
	add_to_group("clock")
	_start_x = position.x
	_time = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	_time += delta
	position.y += speed * delta

	var vp_width := get_viewport().get_visible_rect().size.x

	match tier:
		1:
			# Gentle drift
			position.x = _start_x + sin(_time * 1.3) * 48.0
		2:
			# Wide swooping sine
			position.x = _start_x + sin(_time * 2.1) * 145.0
		3:
			# Homes toward player
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0 and is_instance_valid(players[0]):
				position.x = lerpf(position.x, players[0].position.x, delta * 2.4)
			position.x += sin(_time * 3.0) * 16.0 * delta

	position.x = clampf(position.x, 48.0, vp_width - 48.0)

	if position.y > get_viewport().get_visible_rect().size.y + 200.0:
		queue_free()

func flash_hit() -> void:
	var tween := create_tween()
	# Rewinders flash cyan, others flash red
	var hit_color := Color(0.2, 0.9, 1.0, 1.0) if is_rewinder else Color(1.0, 0.15, 0.15, 1.0)
	tween.tween_property(self, "modulate", hit_color, 0.05)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)
