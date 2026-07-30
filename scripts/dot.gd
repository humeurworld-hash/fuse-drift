extends Node2D
class_name MourkDot

# One shard of Mourk on the board — drawn with the crystal art from
# Fuse: Mourk Run, over a soft hue glow.
#   veiled    — shrouded grey; cannot be woven until the veil is lifted
#   resonant  — prismatic; joins a thread of any hue
#   echo_timer— > 0 marks an echo shard: counts down each move and, at zero,
#               rewinds its neighbours' hues (handled by the board)

const RADIUS := 30.0    # logical pick radius (input feel)
const ART := 96.0       # on-screen size of the crystal art
const ECHO_START := 5

var color_idx := 0
var veiled := false
var resonant := false
var echo_timer := 0
var cell := Vector2i.ZERO


func setup(p_color: int, p_cell: Vector2i, p_veiled := false) -> void:
	color_idx = p_color
	cell = p_cell
	veiled = p_veiled
	queue_redraw()


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
	var rect := Rect2(-ART * 0.5, -ART * 0.5, ART, ART)
	if veiled:
		# Grey shroud: the crystal is visible but drained of feeling.
		var tex: Texture2D = G.SHARD_TEXTURES[color_idx]
		draw_circle(Vector2.ZERO, RADIUS * 1.15, Color(0, 0, 0, 0.35))
		draw_texture_rect(tex, rect, false, Color(0.40, 0.42, 0.52, 0.85))
		draw_arc(Vector2.ZERO, RADIUS * 1.25, 0.0, TAU, 40, G.VEIL_COLOR, 3.0)
		return
	if resonant:
		# Prismatic: an icy-white crystal ringed by every hue.
		draw_circle(Vector2.ZERO, RADIUS * 1.6, Color(0.9, 0.93, 1.0, 0.08))
		draw_texture_rect(G.SHARD_TEXTURES[1], rect, false, Color(1.6, 1.6, 1.7))
		var n := G.DOT_COLORS.size()
		for i in n:
			var a0 := TAU * float(i) / float(n) - TAU * 0.25
			draw_arc(Vector2.ZERO, RADIUS * 1.28, a0, a0 + TAU / float(n) * 0.8,
				10, G.DOT_COLORS[i], 3.0)
		return
	# Faint hue halo — just enough to lift the crystal off the dark veil.
	var glow: Color = G.DOT_COLORS[color_idx]
	glow.a = 0.07
	draw_circle(Vector2.ZERO, RADIUS * 1.6, glow)
	draw_texture_rect(G.SHARD_TEXTURES[color_idx], rect, false)
	if echo_timer > 0:
		# Echo badge: a small clock-like disc with the countdown.
		var bpos := Vector2(RADIUS * 0.85, -RADIUS * 0.85)
		draw_circle(bpos, 14.0, Color(0.06, 0.08, 0.14, 0.92))
		draw_arc(bpos, 14.0, 0.0, TAU, 24, Color(0.72, 0.42, 1.00), 2.5)
		draw_arc(bpos, 14.0, -TAU * 0.25,
			-TAU * 0.25 + TAU * float(echo_timer) / float(ECHO_START),
			24, Color(0.98, 0.86, 0.35), 2.5)
		draw_string(ThemeDB.fallback_font, bpos + Vector2(-14, 7), str(echo_timer),
			HORIZONTAL_ALIGNMENT_CENTER, 28, 20, Color(0.95, 0.95, 1.0))
