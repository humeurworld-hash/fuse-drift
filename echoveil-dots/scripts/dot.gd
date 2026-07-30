extends Node2D
class_name MourkDot

# One shard of Mourk on the board.
#
# The art is a single crystal cluster, so each hue is given its own tilt,
# scale and handedness — otherwise five recolours of one silhouette read as
# a jewel-matching game rather than five different feelings. Shards also
# drift and breathe slightly so they hang in the veil instead of sitting in
# sockets.
#
#   veiled    — shrouded grey; cannot be woven until the veil is lifted
#   resonant  — prismatic; a thread may change hue through it
#   echo_timer— > 0 marks an echo shard: counts down each move and, at zero,
#               rewinds its neighbours' hues (handled by the board)

const RADIUS := 30.0    # logical pick radius (input feel)
const ART := 108.0      # on-screen size of the crystal art
const ECHO_START := 5

# Per-hue signature: tilt (rad), scale, mirrored.
const HUE_FORM := [
	{ "rot":  0.00, "scale": 1.06, "flip": false },  # Ember    — upright, largest
	{ "rot":  0.34, "scale": 0.88, "flip": true  },  # Sorrow   — leaning, small
	{ "rot": -0.22, "scale": 0.97, "flip": false },  # Verdant  — steady
	{ "rot":  0.13, "scale": 0.82, "flip": true  },  # Radiance — compact, bright
	{ "rot": -0.46, "scale": 1.00, "flip": false },  # Umbral   — sharply canted
]

var color_idx := 0
var veiled := false
var resonant := false
var echo_timer := 0
var cell := Vector2i.ZERO

var _phase := 0.0
var _jitter := 0.0
var _focus := 1.0


func _ready() -> void:
	_phase = randf() * TAU
	_jitter = randf_range(-0.07, 0.07)
	set_process(true)


func _process(delta: float) -> void:
	_phase += delta * 0.8
	queue_redraw()


func setup(p_color: int, p_cell: Vector2i, p_veiled := false) -> void:
	color_idx = p_color
	cell = p_cell
	veiled = p_veiled
	queue_redraw()


func set_focus(v: float) -> void:
	if is_equal_approx(_focus, v):
		return
	_focus = v
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, v), 0.14)


func unveil() -> void:
	veiled = false
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.12)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)


func shroud() -> void:
	veiled = true
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.10)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14)


func bump() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.07)
	tw.tween_property(self, "scale", Vector2.ONE, 0.10)


func _draw() -> void:
	var form: Dictionary = HUE_FORM[color_idx % HUE_FORM.size()]
	var bob := sin(_phase) * 3.2
	var sway := cos(_phase * 0.7) * 0.03
	var sc: float = form.scale
	var rect := Rect2(-ART * 0.5, -ART * 0.5, ART, ART)

	# Aura first, so it sits behind the crystal — drawn over it, even a faint
	# circle reads as a hard-edged socket. Stacked rings fake a soft falloff.
	if not veiled and not resonant:
		var aura: Color = G.DOT_COLORS[color_idx]
		for i in 5:
			var t := float(i) / 5.0
			aura.a = 0.016 * (1.0 - t)
			draw_circle(Vector2(0, bob), RADIUS * (2.1 - t * 1.0), aura)

	# Suspended in the veil: drift, sway, and a per-hue silhouette.
	draw_set_transform(Vector2(0, bob), form.rot + _jitter + sway,
		Vector2(-sc if form.flip else sc, sc))

	if veiled:
		draw_texture_rect(G.SHARD_TEXTURES[color_idx], rect, false,
			Color(0.34, 0.36, 0.46, 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, RADIUS * 1.2, 0.0, TAU, 40, G.VEIL_COLOR, 2.5)
		return

	if resonant:
		draw_texture_rect(G.SHARD_TEXTURES[1], rect, false, Color(1.7, 1.7, 1.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var n := G.DOT_COLORS.size()
		for i in n:
			var a0 := TAU * float(i) / float(n) - TAU * 0.25
			draw_arc(Vector2.ZERO, RADIUS * 1.24, a0, a0 + TAU / float(n) * 0.78,
				10, G.DOT_COLORS[i], 3.0)
		return

	draw_texture_rect(G.SHARD_TEXTURES[color_idx], rect, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if echo_timer > 0:
		var bpos := Vector2(RADIUS * 0.85, -RADIUS * 0.85)
		draw_circle(bpos, 14.0, Color(0.06, 0.08, 0.14, 0.92))
		draw_arc(bpos, 14.0, 0.0, TAU, 24, Color(0.72, 0.42, 1.00), 2.5)
		draw_arc(bpos, 14.0, -TAU * 0.25,
			-TAU * 0.25 + TAU * float(echo_timer) / float(ECHO_START),
			24, Color(0.98, 0.86, 0.35), 2.5)
		draw_string(ThemeDB.fallback_font, bpos + Vector2(-14, 7), str(echo_timer),
			HORIZONTAL_ALIGNMENT_CENTER, 28, 20, Color(0.95, 0.95, 1.0))
