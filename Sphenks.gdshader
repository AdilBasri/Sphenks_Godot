shader_type canvas_item;

// --- GODOT 4 DÜZELTMESİ ---
// Bu satır, ekranın görüntüsünü shader'a tanıtır.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- AYARLAR ---
uniform float warp_amount : hint_range(0.0, 1.0) = 0.2;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_count : hint_range(100.0, 2000.0) = 600.0;
uniform bool clip_edges = true;

// --- MATEMATİK FONKSİYONLARI ---
vec2 warp(vec2 uv) {
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta.xy, delta.xy);
	float delta4 = delta2 * delta2;
	float delta_offset = delta4 * warp_amount;
	return uv + delta * delta_offset;
}

float vignette(vec2 uv) {
	uv *= 1.0 - uv.xy;
	float frame = 1.0 - smoothstep(vignette_intensity, vignette_intensity - 0.1, uv.x * uv.y * 100.0);
	return frame;
}

// --- ANA DÖNGÜ ---
void fragment() {
	vec2 uv = warp(SCREEN_UV);
	
	// Düzeltilen kısım burası (artık SCREEN_TEXTURE tanındığı için hata vermez)
	vec4 text = texture(SCREEN_TEXTURE, uv);

	float s = sin(uv.y * scanline_count * PI * 2.0);
	s = (s * 0.5 + 0.5) * 0.9 + 0.1;
	vec4 scanlines = vec4(vec3(pow(s, scanline_opacity)), 1.0);
	text *= scanlines;

	float vig = vignette(uv);
	text.rgb *= mix(1.0, vig, vignette_opacity);

	if (clip_edges) {
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			text.rgb = vec3(0.0, 0.0, 0.0);
		}
	}
	
	COLOR = text;
}