extends Node2D
class_name MourkDot

# One shard of Mourk on the board — drawn with the crystal art from
# Fuse: Mourk Run, over a soft hue glow. Veiled shards are shrouded grey
# and cannot be woven until the veil is lifted.

const RADIUS := 30.0    # logical pick radius (input feel)
const ART := 96.0       # on-screen size of the crystal art

var color_idx := 0
var veiled := false
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


func bump() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.07)
	tw.tween_property(self, "scale", Vector2.ONE, 0.10)


func _draw() -> void:
	var tex: Texture2D = G.SHARD_TEXTURES[color_idx]
	var rect := Rect2(-ART * 0.5, -ART * 0.5, ART, ART)
	if veiled:
		# Grey shroud: the crystal is visible but drained of feeling.
		var shadow := Color(0, 0, 0, 0.35)
		draw_circle(Vector2.ZERO, RADIUS * 1.15, shadow)
		draw_texture_rect(tex, rect, false, Color(0.40, 0.42, 0.52, 0.85))
		draw_arc(Vector2.ZERO, RADIUS * 1.25, 0.0, TAU, 40, G.VEIL_COLOR, 3.0)
		return
	# Faint hue halo — just enough to lift the crystal off the dark veil.
	var glow: Color = G.DOT_COLORS[color_idx]
	glow.a = 0.07
	draw_circle(Vector2.ZERO, RADIUS * 1.6, glow)
	draw_texture_rect(tex, rect, false)
