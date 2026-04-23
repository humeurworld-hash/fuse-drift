shader_type canvas_item;

// Vertical scroll accumulator (updated from GDScript each frame)
uniform float scroll_offset : hint_range(0.0, 200.0) = 0.0;
// Per-level scroll speed (UV units per second)
uniform float scroll_speed : hint_range(0.0, 0.5) = 0.04;
// Horizontal parallax driven by player position (-0.5 .. 0.5 of screen width)
uniform float parallax_x : hint_range(-0.5, 0.5) = 0.0;
// Strength of the horizontal parallax (tune per feel)
uniform float parallax_strength : hint_range(0.0, 0.3) = 0.08;

void fragment() {
	vec2 uv = UV;
	// Vertical scroll — fract() wraps the UV so the texture tiles seamlessly
	uv.y = fract(uv.y + scroll_offset * scroll_speed);
	// Horizontal parallax — shifts opposite to player movement for depth feel
	uv.x = fract(uv.x - parallax_x * parallax_strength);
	COLOR = texture(TEXTURE, uv);
}
