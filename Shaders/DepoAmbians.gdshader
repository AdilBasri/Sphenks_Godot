shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.8;
uniform vec4 cold_tint : source_color = vec4(0.05, 0.15, 0.3, 1.0);
uniform float darkness_multiplier : hint_range(0.0, 5.0) = 1.2;

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	
	// Vignette (Kenar karartması)
	float dist = distance(SCREEN_UV, vec2(0.5));
	float vignette = smoothstep(0.9, 1.0 - vignette_intensity, 1.0 - dist);
	
	// Karartma formülü: Rengi kendisiyle ve bi çarpanla çarparak mid-tonları eziyoruz
	// Parlak yerler (fener ışığı = 1.0) hala yüksek kalır.
	vec3 out_color = pow(max(c.rgb, vec3(0.0)), vec3(1.4)) * darkness_multiplier;
	
	// Soğuk metalik tint (mavi)
	out_color = mix(out_color, out_color * cold_tint.rgb * 5.0, 0.3);
	
	// Vignette uygula
	out_color = mix(out_color, out_color * vignette, vignette_opacity);
	
	COLOR = vec4(out_color, c.a);
}
