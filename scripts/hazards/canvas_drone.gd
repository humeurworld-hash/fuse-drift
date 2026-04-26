extends Area2D
class_name CanvasDrone

@export var tier: int = 1
@export var speed: float = 280.0
@export var damage: int = 1

var _time: float = 0.0
var _start_x: float = 0.0
var _swoop_dir: float = 1.0
var speed_mult: float = 1.0

# Near-miss — fires once when the drone crosses the player's Y level
const NEAR_MISS_RADIUS := 90.0
var _near_miss_fired := false

func set_speed_mult(mult: float) -> void:
	speed_mult = mult

func _ready() -> void:
	add_to_group("hazard")
	add_to_group("drone")
	_start_x = position.x
	_swoop_dir = 1.0 if randf() > 0.5 else -1.0
	_time = randf_range(0.0, TAU)
	# Spawn scale-in pop
	scale = Vector2.ZERO
	var spawn_tween := create_tween()
	spawn_tween.tween_property(self, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
			position.x += sin(_time * 3.0) * 18.0 * delta
		4:
			# Aggressive chase with erratic jitter
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0 and is_instance_valid(players[0]):
				var target_x: float = players[0].position.x
				position.x = lerpf(position.x, target_x, delta * 4.0)
			position.x += sin(_time * 6.0) * 22.0 * delta

	position.x = clampf(position.x, 48.0, vp_width - 48.0)

	_check_near_miss()

	if position.y > get_viewport().get_visible_rect().size.y + 200.0:
		queue_free()

func _check_near_miss() -> void:
	if _near_miss_fired:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var pl: Node2D = players[0]
	# Fire once when the drone passes the player's Y level (moving downward past them)
	if position.y < pl.position.y:
		return
	_near_miss_fired = true
	var dist := absf(position.x - pl.position.x)
	if dist < NEAR_MISS_RADIUS:
		var game := get_tree().get_first_node_in_group("game")
		if game and game.has_method("on_near_miss"):
			game.on_near_miss(pl.global_position)

func flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.05)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
