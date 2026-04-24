extends Area2D
class_name MourkShard

enum ShardColor { BLUE, GREEN, YELLOW, ORANGE, PURPLE, RED }

const SHARD_DATA := {
	ShardColor.BLUE:   { "points": 8,  "tint": Color(0.30, 0.65, 1.00, 1.0) },
	ShardColor.GREEN:  { "points": 12, "tint": Color(0.25, 1.00, 0.45, 1.0) },
	ShardColor.YELLOW: { "points": 20, "tint": Color(1.00, 0.92, 0.20, 1.0) },
	ShardColor.ORANGE: { "points": 30, "tint": Color(1.00, 0.55, 0.10, 1.0) },
	ShardColor.PURPLE: { "points": 45, "tint": Color(0.72, 0.28, 1.00, 1.0) },
	ShardColor.RED:    { "points": 60, "tint": Color(1.00, 0.18, 0.18, 1.0) },
}

# Set in the scene inspector — order matches ShardColor enum (BLUE=0 … RED=5)
@export var shard_textures: Array[Texture2D] = []

@export var speed: float = 320.0
@export var spin_speed: float = 2.2

@onready var art: Sprite2D = $Art
@onready var fallback: Polygon2D = $Fallback
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var collect_sound: AudioStreamPlayer2D = $CollectSound

var shard_color: ShardColor = ShardColor.BLUE
var points: int = 8
var _collecting := false

func _ready() -> void:
	add_to_group("mourk")
	points = SHARD_DATA[shard_color]["points"]
	_apply_color()
	rotation = randf_range(-0.25, 0.25)
	art.scale = Vector2(0.07, 0.07)

# Call before add_child so _ready() picks up the colour.
func set_color(color: ShardColor) -> void:
	shard_color = color
	points = SHARD_DATA[color]["points"]
	if is_inside_tree():
		_apply_color()

func _apply_color() -> void:
	var idx := int(shard_color)
	var tex: Texture2D = shard_textures[idx] if idx < shard_textures.size() else null
	if tex != null:
		art.texture = tex
		art.modulate = Color(1, 1, 1, 1)
		art.visible = true
		fallback.visible = false
	else:
		# Coloured diamond fallback if texture slot is empty
		art.visible = false
		fallback.visible = true
		fallback.color = SHARD_DATA[shard_color]["tint"]
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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(art, "scale", Vector2(0.13, 0.13), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.22).set_delay(0.08)
	tween.chain().tween_callback(queue_free)
