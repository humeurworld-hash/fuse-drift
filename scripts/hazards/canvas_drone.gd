extends Area2D
class_name CanvasDrone

@export var tier: int = 1
@export var speed: float = 280.0
@export var damage: int = 1

var _time: float = 0.0
var _start_x: float = 0.0
var _swoop_dir: float = 1.0
var speed_mult: float = 1.0

func set_speed_mult(mult: float) -> void:
	speed_mult = mult

func _ready() -> void:
	add_to_group("hazard")
	add_to_group("drone")
	_start_x = position.x
	_swoop_dir = 1.0 if randf() > 0.5 else -1.0
	_time = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	_time += delta
	position.y += speed * speed_mult * delta

	var vp_width := get_viewport().get_visible_rect().size.x

	match tier:
		1:
			# Gentle drift left/right around spawn x
			position.x = _start_x + sin(_time * 1.4) * 50.0
		2:
			# Wide swooping sine wave
			position.x = _start_x + sin(_time * 2.0) * 130.0
		3:
			# Hunts player X, lerps toward them
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0 and is_instance_valid(players[0]):
				var target_x: float = players[0].position.x
				position.x = lerpf(position.x, target_x, delta * 2.2)
			# Also drifts slightly side-to-side on top of tracking
			position.x += sin(_time * 3.0) * 18.0 * delta

	position.x = clampf(position.x, 48.0, vp_width - 48.0)

	if position.y > get_viewport().get_visible_rect().size.y + 200.0:
		queue_free()

func flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.05)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
