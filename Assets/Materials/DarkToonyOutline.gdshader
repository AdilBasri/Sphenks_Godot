shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.1, 0.05, 0.15, 1.0); // Dark purple toony
uniform float outline_width : hint_range(0.0, 0.1, 0.001) = 0.03;

void vertex() {
	// Push vertices outward along their normal
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
