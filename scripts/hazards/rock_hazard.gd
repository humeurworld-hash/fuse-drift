extends Area2D
class_name RockHazard

@export var speed: float = 420.0
@export var spin_speed: float = 1.8

@onready var art: Sprite2D = $Art
@onready var fallback: Polygon2D = $Fallback
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var break_sound: AudioStreamPlayer2D = $BreakSound

var _breaking := false

# Fixed: added actual project path first
const TEXTURE_PATHS := [
	"res://scenes/hazards/Rock.png",
	"res://assets/art/level1/falling_rock.png",
	"res://assets/art/level1/rock_hazard.png",
	"res://assets/art/level1/rock.png",
]

var horizontal_drift: float = 0.0

func _ready() -> void:
	add_to_group("hazard")
	_setup_visual()
	# Fixed: scale range reduced to fit 256px rock on a 720px screen
	scale = Vector2.ONE * randf_range(0.35, 0.55)
	rotation = randf_range(-0.4, 0.4)
	spin_speed = randf_range(-2.3, 2.3)
	horizontal_drift = randf_range(-38.0, 38.0)
	# Fixed: removed radius override — scale on root already adjusts collision proportionally

func _process(delta: float) -> void:
	position.y += speed * delta
	position.x += horizontal_drift * delta
	rotation += spin_speed * delta
	if position.y > get_viewport_rect().size.y + 180.0:
		queue_free()

func break_apart() -> void:
	if _breaking:
		return
	_breaking = true
	collision_shape.set_deferred("disabled", true)
	break_sound.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.28).set_delay(0.06)
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
	fallback.color = Color("5c4a39")
	fallback.polygon = PackedVector2Array([
		Vector2(-22, -18),
		Vector2(8, -26),
		Vector2(26, -6),
		Vector2(18, 22),
		Vector2(-8, 28),
		Vector2(-28, 8)
	])
