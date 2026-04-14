extends Area2D
class_name Mourk

@export var speed: float = 420.0
@export var spin_speed: float = 3.0

func _ready() -> void:
	add_to_group("mourk")

func _process(delta: float) -> void:
	position.y += speed * delta
	rotation += spin_speed * delta

	if position.y > get_viewport_rect().size.y + 200.0:
		queue_free()
