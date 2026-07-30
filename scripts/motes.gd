extends Node2D
class_name VeilMotes

# Slow-drifting Mourk motes used as an ambient background layer.

const COUNT := 36

var _motes: Array = []
var _area := Vector2(720, 1280)


func _ready() -> void:
	_area = get_viewport_rect().size
	for i in COUNT:
		var col: Color = G.DOT_COLORS[randi() % G.DOT_COLORS.size()]
		col.a = randf_range(0.05, 0.16)
		_motes.append({
			"pos": Vector2(randf() * _area.x, randf() * _area.y),
			"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-26.0, -8.0)),
			"r": randf_range(2.0, 7.0),
			"col": col,
		})


func _process(delta: float) -> void:
	for m in _motes:
		m.pos += m.vel * delta
		if m.pos.y < -12.0:
			m.pos.y = _area.y + 12.0
			m.pos.x = randf() * _area.x
		m.pos.x = wrapf(m.pos.x, -12.0, _area.x + 12.0)
	queue_redraw()


func _draw() -> void:
	for m in _motes:
		var glow: Color = m.col
		glow.a *= 0.4
		draw_circle(m.pos, m.r * 2.2, glow)
		draw_circle(m.pos, m.r, m.col)
