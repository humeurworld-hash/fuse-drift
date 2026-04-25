extends Area2D
class_name MourkShard

enum ShardColor { TEAL, GREEN, ORANGE, PURPLE, GOLD }

const SHARD_DATA := {
	ShardColor.TEAL:   { "points": 10, "tint": Color(0.30, 0.90, 0.85, 1.0), "texture": "res://scenes/pickups/shard blue.png" },
	ShardColor.GREEN:  { "points": 15, "tint": Color(0.40, 1.00, 0.55, 1.0), "texture": "res://scenes/pickups/shard green.png" },
	ShardColor.ORANGE: { "points": 25, "tint": Color(1.00, 0.60, 0.15, 1.0), "texture": "res://scenes/pickups/shard orange.png" },
	ShardColor.PURPLE: { "points": 40, "tint": Color(0.80, 0.35, 1.00, 1.0), "texture": "res://scenes/pickups/shard purple.png" },
	ShardColor.GOLD:   { "points": 55, "tint": Color(1.00, 0.85, 0.15, 1.0), "texture": "res://scenes/pickups/shard yellow.png" },
}

@export var speed: float = 320.0
@export var spin_speed: float = 2.2

@onready var art: Sprite2D = $Art
@onready var fallback: Polygon2D = $Fallback
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var collect_sound: AudioStreamPlayer2D = $CollectSound

var shard_color: ShardColor = ShardColor.TEAL
var points: int = 8
var _collecting := false

func _ready() -> void:
	add_to_group("mourk")
	points = SHARD_DATA[shard_color]["points"]
	_setup_visual()
	rotation = randf_range(-0.25, 0.25)
	art.scale = Vector2(0.14, 0.14)

func set_color(color: ShardColor) -> void:
	shard_color = color
	points = SHARD_DATA[color]["points"]
	if is_inside_tree():
		_setup_visual()

func _setup_visual() -> void:
	var data: Dictionary = SHARD_DATA[shard_color]
	var tex: Texture2D = load(data["texture"]) if ResourceLoader.exists(data["texture"]) else null
	if tex != null:
		art.texture = tex
		art.modulate = Color(1, 1, 1, 1)
		art.visible = true
		fallback.visible = false
		return
	var base_paths := [
		"res://scenes/pickups/shard.png",
		"res://assets/art/level1/mourk_shard.png",
		"res://assets/art/level1/shard.png",
	]
	for path in base_paths:
		if ResourceLoader.exists(path):
			art.texture = load(path)
			art.modulate = data["tint"]
			art.visible = true
			fallback.visible = false
			return
	art.visible = false
	fallback.visible = true
	fallback.color = data["tint"]
	fallback.polygon = PackedVector2Array([
		Vector2(0, -22), Vector2(16, 0),
		Vector2(0, 24),  Vector2(-16, 0)
	])

func _process(delta: float) -> void:
	if _collecting:
		return
	position.y += speed * delta
	rotation += spin_speed * delta
	if position.y > get_viewport_rect().size.y + 180.0:
		queue_free()

func collect() -> void:
	if _collecting:
		return
	_collecting = true
	collision_shape.set_deferred("disabled", true)
	collect_sound.play()
	_burst_particles()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(art, "scale", Vector2(0.21, 0.21), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.22).set_delay(0.08)
	tween.chain().tween_callback(queue_free)

func _burst_particles() -> void:
	var color := SHARD_DATA[shard_color]["tint"] as Color
	var ps := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()

	# Spread in all directions, short burst
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 220.0
	mat.gravity = Vector3(0, 280, 0)
	mat.scale_min = 3.0
	mat.scale_max = 7.0
	mat.color = color

	# Fade out over lifetime
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 1.0))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	ps.process_material = mat
	ps.amount = 18
	ps.lifetime = 0.45
	ps.explosiveness = 0.95   # fire all at once
	ps.one_shot = true
	ps.emitting = true
	ps.z_index = 20

	# Detach from shard so particles outlive it
	get_parent().add_child(ps)
	ps.global_position = global_position

	# Auto-remove after particles finish
	get_tree().create_timer(0.6).timeout.connect(ps.queue_free)
