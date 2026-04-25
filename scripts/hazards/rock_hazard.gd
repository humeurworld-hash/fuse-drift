extends Area2D
class_name RockHazard

@export var speed: float = 420.0
@export var spin_speed: float = 1.8

@onready var art: Sprite2D = $Art
@onready var fallback: Polygon2D = $Fallback
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var break_sound: AudioStreamPlayer2D = $BreakSound
@onready var fall_sound: AudioStreamPlayer2D = $FallSound

const FALL_SOUNDS := [
	"res://assets/audio/rock fall 1.mp3",
	"res://assets/audio/rock fall 2.mp3",
]

var _breaking := false

const TEXTURE_PATHS := [
	"res://scenes/hazards/Rock.png",
	"res://assets/art/level1/falling_rock.png",
	"res://assets/art/level1/rock_hazard.png",
	"res://assets/art/level1/rock.png",
]

var horizontal_drift: float = 0.0
var speed_mult: float = 1.0

func set_speed_mult(mult: float) -> void:
	speed_mult = mult

# Near-miss — fires once when the rock crosses the player's Y level
const NEAR_MISS_RADIUS := 80.0
var _near_miss_fired := false

func _ready() -> void:
	add_to_group("hazard")
	_setup_visual()
	scale = Vector2.ONE * randf_range(0.35, 0.55)
	rotation = randf_range(-0.4, 0.4)
	spin_speed = randf_range(-2.3, 2.3)
	horizontal_drift = randf_range(-38.0, 38.0)
	# Pick randomly between the two fall sounds for variety
	var path: String = FALL_SOUNDS[randi() % FALL_SOUNDS.size()]
	if ResourceLoader.exists(path):
		fall_sound.stream = load(path)
		fall_sound.pitch_scale = randf_range(0.88, 1.12)
		fall_sound.play()

func _process(delta: float) -> void:
	position.y += speed * speed_mult * delta
	position.x += horizontal_drift * delta
	rotation += spin_speed * delta

	_check_near_miss()

	if position.y > get_viewport_rect().size.y + 180.0:
		queue_free()

func _check_near_miss() -> void:
	if _near_miss_fired or _breaking:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var pl: Node2D = players[0]
	# Trigger once when rock passes the player's Y (moving downward past them)
	if position.y < pl.position.y:
		return
	_near_miss_fired = true
	var dist := absf(position.x - pl.position.x)
	if dist < NEAR_MISS_RADIUS:
		var game := get_tree().get_first_node_in_group("game")
		if game and game.has_method("on_near_miss"):
			game.on_near_miss(pl.global_position)

func break_apart() -> void:
	if _breaking:
		return
	_breaking = true
	collision_shape.set_deferred("disabled", true)
	break_sound.play()
	_burst_particles()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.28).set_delay(0.06)
	tween.chain().tween_callback(queue_free)

func _burst_particles() -> void:
	var ps := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()

	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 120.0
	mat.initial_velocity_max = 340.0
	mat.gravity = Vector3(0, 420, 0)
	mat.scale_min = 4.0
	mat.scale_max = 10.0
	mat.color = Color(0.62, 0.50, 0.36, 1.0)   # sandy rock colour

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.75, 0.62, 0.44, 1.0))
	gradient.set_color(1, Color(0.40, 0.30, 0.20, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	ps.process_material = mat
	ps.amount = 22
	ps.lifetime = 0.55
	ps.explosiveness = 0.92
	ps.one_shot = true
	ps.emitting = true
	ps.z_index = 20

	get_parent().add_child(ps)
	ps.global_position = global_position
	get_tree().create_timer(0.7).timeout.connect(ps.queue_free)

func flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.1, 1.0), 0.05)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

func _setup_visual() -> void:
	for texture_path in TEXTURE_PATHS:
		if ResourceLoader.exists(texture_path):
			art.texture = load(texture_path)
			art.visible = true
			fallback.visible = false
			# Apply outline shader so rocks pop against dark backgrounds
			var mat := ShaderMaterial.new()
			mat.shader = load("res://shaders/hazard_outline.gdshader")
			art.material = mat
			return
	# Fallback polygon — use a bright contrasting colour
	art.visible = false
	fallback.visible = true
	fallback.color = Color("ff9922")   # orange — readable against any background
	fallback.polygon = PackedVector2Array([
		Vector2(-22, -18),
		Vector2(8, -26),
		Vector2(26, -6),
		Vector2(18, 22),
		Vector2(-8, 28),
		Vector2(-28, 8)
	])
