extends Area2D
class_name Player

signal hit
signal mourk_collected(points: int, world_pos: Vector2)
signal health_changed(new_health: int)
signal dash_activated
signal magnet_activated
signal magnet_deactivated

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

# Position history for rewind
var _pos_history: PackedFloat32Array = PackedFloat32Array()
var _history_timer: float = 0.0
const HISTORY_INTERVAL := 0.08
const HISTORY_SAMPLES := 40

# Rewind state
var _rewinding: bool = false
var _rewind_timer: float = 0.0
const REWIND_SLUGGISH_DURATION := 1.6

# ── Ghost Dash ────────────────────────────────────────────────────────────────
const DASH_DURATION    := 0.45   # seconds of invincibility / ghost look
const DASH_COOLDOWN    := 3.5    # seconds before dash is ready again
var _dash_cooldown: float = 0.0
var _dashing: bool = false

# ── Shard Magnet Pulse ────────────────────────────────────────────────────────
const MAGNET_DURATION  := 1.8    # seconds the pull lasts
const MAGNET_COOLDOWN  := 5.0    # seconds before pulse is ready again
const MAGNET_RADIUS    := 220.0  # pull range in world pixels
const MAGNET_PULL_NEAR := 660.0  # pull speed when shard is close (px/s)
const MAGNET_PULL_FAR  := 240.0  # pull speed at edge of radius

var _magnet_active: bool = false
var _magnet_timer: float = 0.0
var _magnet_cooldown: float = 0.0
var _magnet_tween: Tween = null

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

	# ── Invincibility timer ──────────────────────────────────────────────────
	if _invincibility_timer > 0.0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			invincible = false
			if not _magnet_active:   # don't clobber magnet glow
				modulate = Color(1, 1, 1, 1)
			_dashing = false

	# ── Dash cooldown ────────────────────────────────────────────────────────
	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - delta)

	# ── Rewind sluggish timer ────────────────────────────────────────────────
	if _rewind_timer > 0.0:
		_rewind_timer -= delta
		if _rewind_timer <= 0.0:
			_rewinding = false

	# ── Magnet active ────────────────────────────────────────────────────────
	if _magnet_active:
		_magnet_timer -= delta
		_pull_nearby_shards(delta)
		if _magnet_timer <= 0.0:
			_end_magnet()
	if _magnet_cooldown > 0.0:
		_magnet_cooldown = maxf(0.0, _magnet_cooldown - delta)

	# ── Movement ─────────────────────────────────────────────────────────────
	var lerp_speed := move_lerp_speed * 0.3 if _rewinding else move_lerp_speed
	position.x = lerpf(position.x, target_x, delta * lerp_speed)
	position.x = clampf(position.x, screen_padding, screen_size.x - screen_padding)
	position.y = screen_size.y * fixed_y_ratio

	_record_history(delta)
	_update_animation()
	_check_overlaps()

# ── Ghost Dash ────────────────────────────────────────────────────────────────

func can_dash() -> bool:
	return _dash_cooldown <= 0.0 and not _dashing and alive and controls_enabled

func get_dash_cooldown() -> float:
	return _dash_cooldown

func try_dash() -> void:
	if not can_dash():
		return
	_dashing = true
	_dash_cooldown = DASH_COOLDOWN
	invincible = true
	_invincibility_timer = DASH_DURATION
	# Ghost: translucent cool-blue; doesn't override magnet glow if both somehow active
	modulate = Color(0.55, 0.88, 1.0, 0.40)
	if sprite:
		_current_anim = &""          # force animation update next frame
	dash_activated.emit()

# ── Shard Magnet Pulse ────────────────────────────────────────────────────────

func can_magnet() -> bool:
	return _magnet_cooldown <= 0.0 and not _magnet_active and alive and controls_enabled

func get_magnet_cooldown() -> float:
	return _magnet_cooldown

func try_magnet() -> void:
	if not can_magnet():
		return
	_magnet_active = true
	_magnet_timer = MAGNET_DURATION
	_magnet_cooldown = MAGNET_COOLDOWN
	# Pulsing golden glow while magnet runs
	if _magnet_tween and _magnet_tween.is_valid():
		_magnet_tween.kill()
	_magnet_tween = create_tween().set_loops()
	_magnet_tween.tween_property(self, "modulate", Color(1.0, 0.90, 0.25, 1.0), 0.28).set_trans(Tween.TRANS_SINE)
	_magnet_tween.tween_property(self, "modulate", Color(1.0, 1.0,  1.0,  1.0), 0.28).set_trans(Tween.TRANS_SINE)
	magnet_activated.emit()

func _end_magnet() -> void:
	_magnet_active = false
	if _magnet_tween and _magnet_tween.is_valid():
		_magnet_tween.kill()
	_magnet_tween = null
	if not _dashing:
		modulate = Color(1, 1, 1, 1)
	magnet_deactivated.emit()

func _pull_nearby_shards(delta: float) -> void:
	for area in get_tree().get_nodes_in_group("mourk"):
		if not is_instance_valid(area):
			continue
		if area.get("_collecting") == true:
			continue
		var to_player: Vector2 = global_position - area.global_position
		var dist := to_player.length()
		if dist <= 1.0 or dist > MAGNET_RADIUS:
			continue
		var t := 1.0 - (dist / MAGNET_RADIUS)        # 0 at edge, 1 when close
		var speed := lerpf(MAGNET_PULL_FAR, MAGNET_PULL_NEAR, t)
		area.global_position += to_player.normalized() * speed * delta

# ── History & animation ───────────────────────────────────────────────────────

func _record_history(delta: float) -> void:
	_history_timer += delta
	if _history_timer >= HISTORY_INTERVAL:
		_history_timer = 0.0
		_pos_history.append(position.x)
		while _pos_history.size() > HISTORY_SAMPLES:
			_pos_history.remove_at(0)

func _update_animation() -> void:
	# Don't fight the glitch anim during rewind or dash
	if _rewinding:
		return
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

# ── Overlaps ──────────────────────────────────────────────────────────────────

func _check_overlaps() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("hazard"):
			if not invincible and alive:
				var rewinder: bool = area.get("is_rewinder") if area.get("is_rewinder") != null else false
				if rewinder:
					area.flash_hit()
					apply_rewind()
				else:
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

# ── Rewind ────────────────────────────────────────────────────────────────────

func apply_rewind() -> void:
	if invincible or not alive:
		return
	var steps_back := int(2.4 / HISTORY_INTERVAL)
	var rewind_x: float
	if _pos_history.size() >= steps_back:
		rewind_x = _pos_history[_pos_history.size() - steps_back]
	elif _pos_history.size() > 0:
		rewind_x = _pos_history[0]
	else:
		rewind_x = screen_size.x * 0.5
	position.x = rewind_x
	target_x = rewind_x
	_rewinding = true
	_rewind_timer = REWIND_SLUGGISH_DURATION
	invincible = true
	_invincibility_timer = INVINCIBILITY_DURATION
	if sprite:
		_current_anim = &""
		sprite.play(&"glitch")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.2, 0.9, 1.0, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.6), 0.3)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	tween.tween_callback(func():
		if alive and sprite:
			_current_anim = &""
			_rewinding = false
	)

# ── Hit / health ──────────────────────────────────────────────────────────────

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

# ── Input ─────────────────────────────────────────────────────────────────────

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

# ── Setup / reset ─────────────────────────────────────────────────────────────

func setup(hp: int) -> void:
	max_health = hp
	health = hp
	invincible = false
	_invincibility_timer = 0.0
	_rewinding = false
	_rewind_timer = 0.0
	_dash_cooldown = 0.0
	_dashing = false
	_magnet_active = false
	_magnet_timer = 0.0
	_magnet_cooldown = 0.0
	if _magnet_tween and _magnet_tween.is_valid():
		_magnet_tween.kill()
	_magnet_tween = null

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
	if _magnet_tween and _magnet_tween.is_valid():
		_magnet_tween.kill()
	_magnet_tween = null

func die() -> void:
	if not alive:
		return
	alive = false
	controls_enabled = false
	dragging = false
	invincible = false
	_rewinding = false
	_dashing = false
	_magnet_active = false
	if _magnet_tween and _magnet_tween.is_valid():
		_magnet_tween.kill()
	_magnet_tween = null
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
	_rewinding = false
	_rewind_timer = 0.0
	_dash_cooldown = 0.0
	_dashing = false
	_magnet_active = false
	_magnet_timer = 0.0
	_magnet_cooldown = 0.0
	if _magnet_tween and _magnet_tween.is_valid():
		_magnet_tween.kill()
	_magnet_tween = null
	_pos_history.clear()
	_current_anim = &""
	health = max_health
	modulate = Color(1, 1, 1, 1)
	_stop_hover_bob()
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.play(&"hover")
