extends Node2D
class_name MourkDot

# One mote of Mourk on the board. Drawn procedurally: soft glow + core.
# Veiled motes are shrouded grey and cannot be woven until the veil is lifted.

const RADIUS := 30.0

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
	if veiled:
		var shroud := Color(0.14, 0.16, 0.22)
		draw_circle(Vector2.ZERO, RADIUS * 1.08, shroud)
		draw_arc(Vector2.ZERO, RADIUS * 1.08, 0.0, TAU, 40, G.VEIL_COLOR, 3.0)
		var hint: Color = G.DOT_COLORS[color_idx]
		hint.a = 0.18
		draw_circle(Vector2.ZERO, RADIUS * 0.42, hint)
		return
	var col: Color = G.DOT_COLORS[color_idx]
	var glow := col
	glow.a = 0.08
	draw_circle(Vector2.ZERO, RADIUS * 1.85, glow)
	glow.a = 0.16
	draw_circle(Vector2.ZERO, RADIUS * 1.35, glow)
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_circle(Vector2(-RADIUS * 0.3, -RADIUS * 0.3), RADIUS * 0.26, Color(1, 1, 1, 0.35))
