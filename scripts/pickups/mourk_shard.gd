extends Area2D
class_name MourkShard

@export var speed: float = 320.0
@export var spin_speed: float = 2.2

@onready var art: Sprite2D = $Art
@onready var fallback: Polygon2D = $Fallback
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var collect_sound: AudioStreamPlayer2D = $CollectSound

const TEXTURE_PATHS := [
	"res://scenes/pickups/shard.png",
	"res://assets/art/level1/mourk_shard.png",
	"res://assets/art/level1/shard.png",
	"res://assets/art/collectibles/mourk_shard.png",
]

var _collecting := false

func _ready() -> void:
	add_to_group("mourk")
	_setup_visual()
	rotation = randf_range(-0.25, 0.25)
	art.scale = Vector2(0.07, 0.07)

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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(art, "scale", Vector2(0.13, 0.13), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.22).set_delay(0.08)
	tween.chain().tween_callback(queue_free)

func _setup_visual() -> void:
	for texture_path in TEXTURE_PATHS:
		if ResourceLoader.exists(texture_path):
			art.texture = load(texture_path)
			art.visible = true
			fallback.visible = false
			return
	art.visible = false
	fallback.visible = true
	fallback.color = Color("49f2ef")
	fallback.polygon = PackedVector2Array([
		Vector2(0, -22),
		Vector2(16, 0),
		Vector2(0, 24),
		Vector2(-16, 0)
	])
