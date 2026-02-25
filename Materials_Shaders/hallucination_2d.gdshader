// ============================================================
//   HALLUCINATION 2D — Retinal Burn-In Sprite Shader
//   Sphenks Godot Horror Game
// ============================================================
//   Apply this to any Sprite2D or TextureRect containing the
//   2D hallucination images (skulls, cats, dogs, etc.)
//
//   Effect stack (bottom to top):
//     1. Edge Dissolution  — organic, noise-eroded silhouette
//     2. Chromatic Bleed   — RGB channels split at the edges
//     3. Parchment Grime   — brown/black crumbling paper border
//     4. Burn-In Vignette  — overexposed bright interior core
//     5. Multiply-Screen   — physically blends into 3D world
//     6. Flicker           — the image breathes, barely alive
//     7. Grain             — film grain unifies with 3D scene
//
//   SCENE SETUP (recommended Node structure):
//   ──────────────────────────────────────────
//   Node2D  (HallucinationContainer)
//   ├── TextureRect  (parchment_bg)
//   │     texture = dirty noise / parchment texture
//   │     CanvasItem.blend_mode = BLEND_MODE_MUL
//   │     modulate alpha ≈ 0.3–0.5
//   └── Sprite2D  (hallucination_image)
//         texture = skull.png / Kedi_Normal.png / etc.
//         ShaderMaterial → this shader
//
//   The parchment_bg behind multiplies dark papyrus texture into
//   the scene. The Sprite2D on top uses this shader for edge effects.
// ============================================================

shader_type canvas_item;

// ─── CORE ─────────────────────────────────────────────────────
// The main drawing (skull, cat, dog, etc.)
// Godot automatically provides TEXTURE for Sprite2D nodes.

// ─── EDGE DISSOLUTION ─────────────────────────────────────────
// How aggressively noise eats the sprite edges
uniform float dissolution_amount : hint_range(0.0, 1.0) = 0.35;
// Scale of the dissolution noise pattern
uniform float dissolution_scale : hint_range(1.0, 20.0) = 6.0;
// Sharpness of the noise bite — low = soft gradient, high = hard chunks
uniform float dissolution_hardness : hint_range(1.0, 20.0) = 6.0;

// ─── CHROMATIC BLEED ──────────────────────────────────────────
// How far RGB channels split near the sprite edge
uniform float chroma_bleed : hint_range(0.0, 0.08) = 0.025;
// How close to the edge does the bleed kick in
uniform float chroma_edge_radius : hint_range(0.0, 0.5) = 0.22;

// ─── PARCHMENT GRIME ──────────────────────────────────────────
// Dark papyrus burn color
uniform vec4 grime_color : source_color = vec4(0.10, 0.04, 0.02, 1.0);
// How thick the grime border is
uniform float grime_border : hint_range(0.0, 0.5) = 0.20;
// Grime noise scale — how fine-grained the border crumbling is
uniform float grime_scale : hint_range(1.0, 30.0) = 10.0;

// ─── BURN-IN VIGNETTE ─────────────────────────────────────────
// Center glow — bright areas feel overexposed/burned in
uniform float burn_intensity : hint_range(0.0, 1.0) = 0.20;
uniform vec4 burn_color : source_color = vec4(0.95, 0.88, 0.62, 1.0); // bone-white warm

// ─── FLICKER ──────────────────────────────────────────────────
// Overall alpha pulse speed (Hz)
uniform float flicker_speed : hint_range(0.1, 10.0) = 1.8;
// Flicker amount — how much the image breathes
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.12;
// Secondary fast glitch pulse
uniform float glitch_speed : hint_range(0.0, 30.0) = 12.0;
uniform float glitch_amount : hint_range(0.0, 0.3) = 0.06;

// ─── TINT ─────────────────────────────────────────────────────
// Blend the image toward a sickly horror tone
uniform vec4 horror_tint : source_color = vec4(0.8, 0.65, 0.4, 1.0); // jaundiced bone
uniform float tint_strength : hint_range(0.0, 1.0) = 0.30;

// ─── GRAIN ────────────────────────────────────────────────────
uniform float grain_intensity : hint_range(0.0, 0.2) = 0.06;

// ─── NOISE HELPERS ────────────────────────────────────────────

float hash2(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i), hash2(i + vec2(1,0)), u.x),
		mix(hash2(i + vec2(0,1)), hash2(i + vec2(1,1)), u.x),
		u.y
	);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise2(p);
		p = p * 2.1 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}


void fragment() {
	vec2 uv = UV;

	// ── Helper: distance from center & edges ──────────────────
	vec2 center_uv = uv - 0.5;
	float center_dist = length(center_uv);
	// Edge distance: 0 at center, 1 at corners
	float edge_dist = max(abs(center_uv.x), abs(center_uv.y)) * 2.0;

	// ── 1. CHROMATIC BLEED ────────────────────────────────────
	// Compute edge proximity mask
	float edge_mask = smoothstep(chroma_edge_radius, 1.0, edge_dist);
	// Push each channel outward from center at different amounts
	vec2 bleed_dir = normalize(center_uv + vec2(0.0001));
	float r_val = texture(TEXTURE, uv + bleed_dir * chroma_bleed * edge_mask * 0.8).r;
	float g_val = texture(TEXTURE, uv + bleed_dir * chroma_bleed * edge_mask * 0.4).g;
	float b_val = texture(TEXTURE, uv - bleed_dir * chroma_bleed * edge_mask * 0.6).b;
	float a_val = texture(TEXTURE, uv).a;
	vec3 color = vec3(r_val, g_val, b_val);

	// ── 2. HORROR TINT ────────────────────────────────────────
	// Pull the sprite image toward sickly bone / jaundice tones
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, color * horror_tint.rgb, tint_strength);

	// ── 3. BURN-IN VIGNETTE ───────────────────────────────────
	// Bright center — like a photographic overexposure
	float burn_mask = 1.0 - smoothstep(0.0, 0.55, center_dist);
	vec3 burned = mix(color, burn_color.rgb, burn_mask * burn_intensity);
	color = burned;

	// ── 4. PARCHMENT GRIME BORDER ────────────────────────────
	// FBM noise shapes the inner edge of the grime overlay
	float grime_noise = fbm2(uv * grime_scale);
	// Grime is heaviest at the edges, thinned by noise in the middle
	float grime_mask = edge_dist - grime_border + grime_noise * 0.25;
	grime_mask = smoothstep(0.0, 0.3, grime_mask);
	color = mix(color, grime_color.rgb, grime_mask * 0.85);

	// ── 5. EDGE DISSOLUTION ──────────────────────────────────
	// Noise erodes the alpha at the sprite border — organic silhouette
	float dissolve_noise = fbm2(uv * dissolution_scale + vec2(TIME * 0.08));
	// Convert edge distance to a 0→1 fade zone
	float alpha_edge = 1.0 - smoothstep(0.5 - dissolution_amount, 0.5, edge_dist);
	// Noise bites into the fade zone
	float noise_bite = pow(dissolve_noise, dissolution_hardness * 0.5);
	float dissolved_alpha = alpha_edge * (1.0 - noise_bite * dissolution_amount * 1.5);
	dissolved_alpha = clamp(dissolved_alpha, 0.0, 1.0);

	// ── 6. FLICKER ────────────────────────────────────────────
	// Primary slow breath
	float breath = sin(TIME * flicker_speed) * 0.5 + 0.5;
	// Secondary fast glitch spike
	float t_glitch = floor(TIME * glitch_speed);
	float glitch = hash2(vec2(t_glitch, 0.3)) < glitch_amount ? 0.7 : 1.0;
	float flicker_mult = (1.0 - flicker_amount) + breath * flicker_amount;
	float final_flicker = flicker_mult * glitch;

	// ── 7. FILM GRAIN ─────────────────────────────────────────
	float grain_t = floor(TIME * 24.0);
	float grain = hash2(uv * 800.0 + vec2(grain_t)) * 2.0 - 1.0;
	color += grain * grain_intensity;

	// ── 8. FINAL ALPHA ────────────────────────────────────────
	// Combine texture alpha, dissolution, and flicker
	float final_alpha = a_val * dissolved_alpha * final_flicker;

	// Blend mode hint: for multiply-screen dual blend, set this
	// Sprite2D's CanvasItem.blend_mode to BLEND_MODE_ADD in cases
	// where you want the hallucination to glow through.
	COLOR = vec4(clamp(color, 0.0, 1.0), clamp(final_alpha, 0.0, 1.0));
}
