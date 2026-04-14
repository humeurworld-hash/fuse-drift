extends Area2D
class_name FallingHazard

@export var speed: float = 480.0
@export var spin_speed: float = 1.5
@export var damage: int = 1

func _ready() -> void:
	add_to_group("hazard")

func _process(delta: float) -> void:
	position.y += speed * delta
	rotation += spin_speed * delta

	if position.y > get_viewport_rect().size.y + 200.0:
		queue_free()
