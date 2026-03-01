// ============================================================
//   TEXTURE CRUNCH — Material Degradation Shader
//   Sphenks Godot Horror Game
// ============================================================
//   Apply this to ANY MeshInstance3D to instantly destroy
//   clean PBR materials and make them look ancient, dirty,
//   low-res, and retro. Think PS1-era textures dug out of
//   corrupted memory.
// ============================================================

shader_type spatial;

// Kill all PBR — unshaded-adjacent flat brutalism
render_mode diffuse_lambert, specular_disabled;

// ─── TEXTURE ─────────────────────────────────────────────────
// Use filter_nearest on this sampler for hard-pixel look.
// Note: Nearest is set per-import in Godot 4, but we enforce
// quantized UV sampling below to simulate it in-shader.
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);

// ─── POSTERIZATION ────────────────────────────────────────────
// Quantize RGB into N flat color steps. 3-5 is the sweet spot
// for that dirty comic-book horror look.
uniform float posterize_steps : hint_range(2.0, 16.0) = 4.0;

// ─── DESATURATION CRUSH ───────────────────────────────────────
// Pull all colors toward a sickly yellow-brown baseline before
// posterizing. 0.0 = full original color, 1.0 = full sickly mono.
uniform float desaturate_amount : hint_range(0.0, 1.0) = 0.35;
// The "sickly tone" — bone yellow, ancient parchment
uniform vec3 sickly_tone : source_color = vec3(0.72, 0.60, 0.38);

// ─── DIRT / GRIME OVERLAY ─────────────────────────────────────
uniform float dirt_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float dirt_scale : hint_range(1.0, 64.0) = 12.0;
// Dark grime color — dried blood, ancient soot
uniform vec3 dirt_color : source_color = vec3(0.08, 0.03, 0.02);

// ─── UV QUANTIZATION (Pixel-Grid Snap) ───────────────────────
// Snaps UV to a coarse grid, making the texture visibly blocky
// even if the asset import isn't set to Nearest.
uniform float pixel_grid_size : hint_range(8.0, 512.0) = 64.0;

// ─── SCRATCH / DAMAGE LINES ───────────────────────────────────
uniform float scratch_intensity : hint_range(0.0, 1.0) = 0.25;

// ─── EDGE DARKENING (Dirt Accumulation) ──────────────────────
// Makes UV edges and seams darker, simulates collected filth
uniform float edge_dirt : hint_range(0.0, 1.0) = 0.3;

// ─── MATERIAL OUTPUT KILL ─────────────────────────────────────
// These are hard-overridden — no gloss survives
// (set in fragment below)


// ─── NOISE HELPERS ────────────────────────────────────────────

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

// Value noise
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i + vec2(0,0)), hash21(i + vec2(1,0)), u.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x),
		u.y
	);
}

// Fractal Brownian Motion — layered noise for organic dirt
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

// Horizontal scratch lines — like an old VHS tape
float scratches(vec2 uv, float intensity) {
	float line = floor(uv.y * 80.0);
	float rng = hash21(vec2(line, floor(TIME * 3.0)));
	float scratch = step(1.0 - intensity * 0.15, rng);
	float x_rng = hash21(vec2(uv.x * 10.0, line));
	return scratch * step(0.4, x_rng) * 0.6;
}


void fragment() {
	vec2 base_uv = UV * uv_scale;
	
	// ── 1. UV QUANTIZATION ──────────────────────────────────────
	// Snap UVs to a pixel grid to enforce hard-pixel look
	vec2 snapped_uv = floor(base_uv * pixel_grid_size) / pixel_grid_size;

	// ── 2. SAMPLE TEXTURE (with snapped UVs) ────────────────────
	vec4 tex = texture(albedo_texture, snapped_uv) * albedo_tint;
	vec3 color = tex.rgb;

	// ── 3. DESATURATION CRUSH ───────────────────────────────────
	// Pull toward sickly bone-yellow to unify all textures
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 sickly = mix(vec3(luma), sickly_tone, 0.6); // bone-tinted mono
	color = mix(color, sickly, desaturate_amount);

	// ── 4. POSTERIZATION ────────────────────────────────────────
	// Quantize each channel — hard flat color bands
	color = floor(color * posterize_steps + 0.5) / posterize_steps;

	// ── 5. FBM DIRT OVERLAY ─────────────────────────────────────
	// Two layers of organic noise for deep, layered grime
	vec2 dirt_uv = base_uv * dirt_scale;
	float dirt_layer1 = fbm(dirt_uv);
	float dirt_layer2 = fbm(dirt_uv * 2.3 + vec2(7.1, 3.7));
	// Multiply layers for concentrated dark spots
	float dirt_mask = pow(dirt_layer1, 1.5) * (0.6 + dirt_layer2 * 0.4);
	// Remap: only the darkest patches become heavy grime
	dirt_mask = smoothstep(0.3, 0.85, dirt_mask);
	// Blend dirt into the base color
	color = mix(color, dirt_color, dirt_mask * dirt_intensity);

	// ── 6. EDGE DIRT (UV-SEAM ACCUMULATION) ─────────────────────
	// Darken pixels near UV edges (0 and 1) — seam grime
	vec2 edge_dist = min(base_uv, 1.0 - base_uv); // 0 at edges, 0.5 at center
	float edge_factor = 1.0 - smoothstep(0.0, 0.08, min(edge_dist.x, edge_dist.y));
	color = mix(color, dirt_color, edge_factor * edge_dirt);

	// ── 7. SCRATCH / DAMAGE LINES ───────────────────────────────
	float scratch = scratches(base_uv, scratch_intensity);
	color = mix(color, vec3(0.9, 0.85, 0.7), scratch * 0.6); // Light scratches
	color = mix(color, vec3(0.0), scratch * 0.4);              // Dark scratch depth

	// ── 8. FINAL POSTERIZE PASS (Post-Dirt) ─────────────────────
	// A second lighter posterize after dirt to unify the tones
	color = floor(color * (posterize_steps * 1.5) + 0.5) / (posterize_steps * 1.5);

	// ── 9. PBR KILL — NO SHINE SURVIVES ─────────────────────────
	ALBEDO = color;
	METALLIC = 0.0;          // Zero metallic — this is filth, not tech
	ROUGHNESS = 1.0;         // Maximum roughness — no specular whatsoever
	SPECULAR = 0.0;          // Kill all specular
	ALPHA = tex.a;

	// ── 10. VERY SUBTLE EMISSION (Faint glow on bright bone tones) ──
	// Makes highlights feel eerily lit from within, not reflected
	float bright_mask = smoothstep(0.65, 0.9, luma);
	EMISSION = color * bright_mask * 0.08;
}
