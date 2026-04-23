shader_type canvas_item;

// Bright outline colour — warm orange contrasts well against the dark cave/space backgrounds
uniform vec4 outline_color : source_color = vec4(1.0, 0.72, 0.18, 1.0);
// How far the outline extends in pixels (applied in texture-pixel units)
uniform float outline_size : hint_range(0.5, 8.0) = 2.8;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 step = outline_size * TEXTURE_PIXEL_SIZE;

	// Sample 8 neighbours — diagonals weighted slightly less
	float n = 0.0;
	n += texture(TEXTURE, UV + vec2( step.x,  0.0   )).a;
	n += texture(TEXTURE, UV + vec2(-step.x,  0.0   )).a;
	n += texture(TEXTURE, UV + vec2( 0.0,     step.y)).a;
	n += texture(TEXTURE, UV + vec2( 0.0,    -step.y)).a;
	n += texture(TEXTURE, UV + vec2( step.x,  step.y)).a * 0.75;
	n += texture(TEXTURE, UV + vec2(-step.x,  step.y)).a * 0.75;
	n += texture(TEXTURE, UV + vec2( step.x, -step.y)).a * 0.75;
	n += texture(TEXTURE, UV + vec2(-step.x, -step.y)).a * 0.75;

	// Outline appears only outside the sprite (where base.a is near 0)
	float outline_mask = clamp(n, 0.0, 1.0) * (1.0 - ceil(base.a));

	// Blend: sprite pixels show normally; empty pixels around the sprite get the outline
	COLOR = mix(vec4(outline_color.rgb, outline_mask), base, base.a);
	COLOR.a = max(base.a, outline_mask * outline_color.a);
}
