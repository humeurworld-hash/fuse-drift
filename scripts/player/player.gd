extends Area2D
class_name Player

signal hit
signal mourk_collected(points: int, world_pos: Vector2)
signal health_changed(new_health: int)

@export var move_lerp_speed: float = 16.0
@export var screen_padding: float = 48.0
@export var fixed_y_ratio: float = 0.82

var screen_size: Vector2
var target_x: float
var dragging := false
var drag_offset_x := 0.0
var alive := false
var controls_enabled := false

var health: int = 1
var max_health: int = 1
var invincible: bool = false
var _invincibility_timer: float = 0.0
const INVINCIBILITY_DURATION := 1.2

var _current_anim: StringName = &""
var _bob_tween: Tween = null

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

	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			invincible = false
			modulate = Color(1, 1, 1, 1)

	position.x = lerpf(position.x, target_x, delta * move_lerp_speed)
	position.x = clampf(position.x, screen_padding, screen_size.x - screen_padding)
	position.y = screen_size.y * fixed_y_ratio
	_update_animation()
	_check_overlaps()

func _update_animation() -> void:
	var dx := target_x - position.x
	var new_anim: StringName
	if dx < -10.0:
		new_anim = &"move_left"
	elif dx > 10.0:
		new_anim = &"move_right"
	else:
		new_anim = &"hover"
	if new_anim != _current_anim:
		_current_anim = new_anim
		sprite.play(new_anim)
		if new_anim == &"hover":
			_start_hover_bob()
		else:
			_stop_hover_bob()

func _start_hover_bob() -> void:
	_stop_hover_bob()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(sprite, "position", Vector2(0, -5), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(sprite, "position", Vector2(0, 0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_hover_bob() -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null
	if sprite:
		sprite.position = Vector2.ZERO

func _check_overlaps() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("hazard"):
			if not invincible and alive:
				if area.has_method("break_apart"):
					area.break_apart()
				elif area.has_method("flash_hit"):
					area.flash_hit()
			var dmg: int = area.get("damage") if area.get("damage") != null else 1
			take_hit(dmg)
			return
		elif area.is_in_group("mourk"):
			if is_instance_valid(area) and area.has_method("collect"):
				mourk_collected.emit(5, area.global_position)
				area.collect()

func take_hit(damage: int) -> void:
	if invincible or not alive:
		return
	health -= damage
	health = max(health, 0)
	health_changed.emit(health)
	_flash_red()
	if health <= 0:
		die()
		return
	invincible = true
	_invincibility_timer = INVINCIBILITY_DURATION

func _flash_red() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.15, 0.15, 1.0), 0.06)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)

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

func setup(hp: int) -> void:
	max_health = hp
	health = hp
	invincible = false
	_invincibility_timer = 0.0

func enable_control() -> void:
	alive = true
	controls_enabled = true
	dragging = false
	modulate = Color(1, 1, 1, 1)
	_current_anim = &""
	if sprite:
		sprite.play(&"hover")
		_start_hover_bob()

func disable_control() -> void:
	controls_enabled = false
	dragging = false
	_stop_hover_bob()

func die() -> void:
	if not alive:
		return
	alive = false
	controls_enabled = false
	dragging = false
	invincible = false
	_stop_hover_bob()
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.play(&"damaged")
	hit.emit()

func reset_player() -> void:
	screen_size = get_viewport_rect().size
	position = Vector2(screen_size.x * 0.5, screen_size.y * fixed_y_ratio)
	target_x = position.x
	dragging = false
	alive = false
	invincible = false
	_invincibility_timer = 0.0
	_current_anim = &""
	health = max_health
	modulate = Color(1, 1, 1, 1)
	_stop_hover_bob()
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.play(&"hover")
