shader_type canvas_item;

uniform float glitch_amount = 0.1;
uniform sampler2D noise_texture;

void fragment() {
	vec2 uv = UV;
	
	// Create glitch distortion
	float glitch = sin(uv.y * 6.0 + TIME * 20.0) * glitch_amount;
	uv.x += glitch;
	
	// Sample with distortion
	vec4 color = texture(TEXTURE, uv);
	
	// Add red tint and noise
	color.r += 0.3;
	color.g -= 0.2;
	color.b -= 0.2;
	
	// Add scan lines
	float scanline = sin(uv.y * 100.0) * 0.1;
	color.rgb += scanline;
	
	COLOR = color;
}