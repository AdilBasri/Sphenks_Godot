shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.05, 0.08, 0.03, 1.0);
uniform vec4 melt_color : source_color = vec4(0.4, 0.6, 0.0, 1.0);
uniform float melt_strength : hint_range(0.0, 1.0) = 0.6;
uniform float drip_speed : hint_range(0.0, 5.0) = 1.2;
uniform float drip_scale : hint_range(1.0, 20.0) = 6.0;
uniform float edge_glow : hint_range(0.0, 3.0) = 1.4;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.8;

void vertex() {
	// Aşağı doğru damlama — Y ekseninde eriyik sarkma
	float drip = sin(VERTEX.x * drip_scale + TIME * drip_speed) * 0.5 + 0.5;
	drip *= sin(VERTEX.z * drip_scale * 0.7 + TIME * drip_speed * 0.8) * 0.5 + 0.5;
	// Sadece aşağı sarkar, yukarı çıkmaz
	float sag = clamp(-VERTEX.y * 0.3, 0.0, 1.0) * drip * melt_strength * 0.04;
	VERTEX.y -= sag;
	VERTEX.x += sin(TIME * drip_speed + VERTEX.y * 4.0) * sag * 0.3;
}

void fragment() {
	// UV'ye göre eriyik renk geçişi
	float melt_pattern = sin(UV.x * drip_scale + TIME * drip_speed * 0.5) * 0.5 + 0.5;
	melt_pattern *= sin(UV.y * drip_scale * 1.3) * 0.5 + 0.5;
	
	// Kenar parlama (fresnel) — eriyik damlaların kenarı parlasın
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0) * edge_glow;
	
	vec4 final_color = mix(base_color, melt_color, melt_pattern * melt_strength);
	final_color.rgb += vec3(0.1, 0.2, 0.0) * fresnel;
	
	ALBEDO = final_color.rgb;
	ROUGHNESS = roughness_val;
	METALLIC = 0.1;
	// Hafif emisyon — eriyik kısımlar içten parlar
	EMISSION = melt_color.rgb * fresnel * 0.4;
}