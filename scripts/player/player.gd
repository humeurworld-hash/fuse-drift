extends Area2D
class_name Player

signal hit
signal mourk_collected(points: int)

@export var move_lerp_speed: float = 16.0
@export var screen_padding: float = 48.0
@export var fixed_y_ratio: float = 0.82

var screen_size: Vector2
var target_x: float
var dragging := false
var drag_offset_x := 0.0
var alive := false
var controls_enabled := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	screen_size = get_viewport_rect().size
	position = Vector2(screen_size.x * 0.5, screen_size.y * fixed_y_ratio)
	target_x = position.x
	disable_control()

func _process(delta: float) -> void:
	if not alive:
		return
	position.x = lerpf(position.x, target_x, delta * move_lerp_speed)
	position.x = clampf(position.x, screen_padding, screen_size.x - screen_padding)
	position.y = screen_size.y * fixed_y_ratio
	_check_overlaps()

func _check_overlaps() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("hazard"):
			die()
			return
		elif area.is_in_group("mourk"):
			if is_instance_valid(area):
				mourk_collected.emit(5)
				area.queue_free()

func _input(event: InputEvent) -> void:
	if not alive or not controls_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			drag_offset_x = position.x - event.position.x
			target_x = event.position.x + drag_offset_x
		else:
			dragging = false
	elif event is InputEventScreenDrag and dragging:
		target_x = event.position.x + drag_offset_x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset_x = position.x - event.position.x
			target_x = event.position.x + drag_offset_x
	elif event is InputEventMouseMotion and dragging:
		target_x = event.position.x + drag_offset_x

func enable_control() -> void:
	alive = true
	controls_enabled = true
	dragging = false
	modulate = Color(1, 1, 1, 1)
	if sprite:
		sprite.play(&"hover")

func disable_control() -> void:
	controls_enabled = false
	dragging = false

func die() -> void:
	if not alive:
		return
	alive = false
	controls_enabled = false
	dragging = false
	if sprite:
		sprite.play(&"damaged")
	hit.emit()

func reset_player() -> void:
	screen_size = get_viewport_rect().size
	position = Vector2(screen_size.x * 0.5, screen_size.y * fixed_y_ratio)
	target_x = position.x
	dragging = false
	alive = false
	modulate = Color(1, 1, 1, 1)
	if sprite:
		sprite.play(&"hover")
