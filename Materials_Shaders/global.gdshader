// ============================================================
//   GLOBAL POST-PROCESS — Egyptian Cult Color Grading
//   Sphenks Godot Horror Game
// ============================================================
//   Apply this shader to a full-screen ColorRect that sits on
//   top of a SubViewportContainer (or use it as a CanvasLayer
//   shader). It reads the screen texture and re-tones the
//   entire world into the strict 4-tone horror palette.
//
//   PALETTE:
//     Pitch Black  (#0D0000) — crushed shadows, void
//     Crimson Red  (#8B0000) — blood, danger, cult symbols
//     Ashen Grey   (#3D3530) — flesh, dust, mummies (midtone)
//     Desert Gold  (#C89A3A) — bone, candlelight, highlights
// ============================================================

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// ─── BASIC ADJUSTMENTS ────────────────────────────────────────
uniform float brightness : hint_range(0.5, 2.0) = 0.88;   // Slightly underexposed — oppressive
uniform float contrast   : hint_range(0.5, 2.5) = 1.38;   // High contrast — shadows crushed
uniform float saturation : hint_range(0.0, 2.0) = 0.42;   // Almost desaturated — palette dominates

// ─── EGYPTIAN CULT PALETTE ────────────────────────────────────
// These four tones replace the natural color ramp of the scene.
uniform vec4 tone_shadow   : source_color = vec4(0.05, 0.00, 0.00, 1.0); // Pitch Black (blood-tinted void)
uniform vec4 tone_crimson  : source_color = vec4(0.55, 0.02, 0.02, 1.0); // Crimson — deep blood red
uniform vec4 tone_ash      : source_color = vec4(0.24, 0.21, 0.19, 1.0); // Ashen Grey — dead flesh midtone
uniform vec4 tone_gold     : source_color = vec4(0.78, 0.60, 0.23, 1.0); // Desert Gold — bone & candlelight

// How aggressively the palette replaces original color
// 0.0 = original game colors, 1.0 = full palette dominance
uniform float palette_strength : hint_range(0.0, 1.0) = 0.58;

// Crimson bleed — how much red gets baked into the midtones
// (makes even light grey areas feel slightly bloodstained)
uniform float crimson_bleed : hint_range(0.0, 1.0) = 0.18;

// ─── CHROMATIC ABERRATION ─────────────────────────────────────
uniform float ca_strength : hint_range(0.0, 0.02) = 0.004;

// ─── FILM GRAIN ───────────────────────────────────────────────
uniform float grain_amount : hint_range(0.0, 0.15) = 0.055;

// ─── VIGNETTE ─────────────────────────────────────────────────
uniform float vignette_intensity : hint_range(0.0, 3.0) = 0.55;
// Vignette tint — pull the dark edges toward blood red
uniform vec3 vignette_color : source_color = vec3(0.04, 0.0, 0.0);

// ─── SCANLINES (CRT / Retro dirt) ─────────────────────────────
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.10;
uniform float scanline_count : hint_range(100.0, 1080.0) = 300.0; // Lines per screen

// ─── DITHERING ────────────────────────────────────────────────
// Bayer-matrix style dithering applied before posterize to
// prevent solid bands — gives a grimy halftone print feel
uniform float dither_amount : hint_range(0.0, 0.1) = 0.025;

// ─── NOISE ────────────────────────────────────────────────────
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Bayer 4x4 ordered dithering matrix
float bayer4(vec2 pos) {
	float bayer[16] = float[16](
		 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
		12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
		 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
		15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
	);
	int x = int(mod(pos.x, 4.0));
	int y = int(mod(pos.y, 4.0));
	return bayer[y * 4 + x];
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// ── 1. CHROMATIC ABERRATION ──────────────────────────────────
	// R channel shifts right, B shifts left — lens splitting effect
	float r = texture(SCREEN_TEXTURE, uv + vec2(ca_strength, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(ca_strength, 0.0)).b;
	vec3 color = vec3(r, g, b);

	// ── 2. BRIGHTNESS & CONTRAST ────────────────────────────────
	// Contrast: pivot at 0.5 — shadows crushed down, brights boosted
	color = (color - 0.5) * contrast + 0.5;
	color *= brightness;
	color = clamp(color, 0.0, 1.0);

	// ── 3. SATURATION CRUSH ─────────────────────────────────────
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);

	// ── 4. CRIMSON BLEED INTO MIDTONES ──────────────────────────
	// Even grey surfaces get a barely-perceptible blood stain
	float mid_mask = smoothstep(0.0, 0.5, luma) * (1.0 - smoothstep(0.5, 1.0, luma));
	color = mix(color, color * vec3(1.0 + crimson_bleed * 0.4, 1.0 - crimson_bleed * 0.1, 1.0 - crimson_bleed * 0.15), mid_mask * crimson_bleed);

	// ── 5. FOUR-TONE PALETTE MAPPING ────────────────────────────
	// The "secret sauce": map the luma ramp to our 4 palette tones
	// using smooth transitions — creates the Sin City duotone feel
	//
	// luma 0.0→0.25 = shadows (Pitch Black)
	// luma 0.15→0.40 = crimson zone (blood red)
	// luma 0.35→0.65 = ash zone (dead grey flesh)
	// luma 0.60→1.00 = gold zone (bone / candlelight)

	vec3 palette_color;
	float t = luma;

	// Ramp through the 4 tones smoothly
	vec3 p_shadow  = tone_shadow.rgb;
	vec3 p_crimson = tone_crimson.rgb;
	vec3 p_ash     = tone_ash.rgb;
	vec3 p_gold    = tone_gold.rgb;

	// Shadow → Crimson
	vec3 sc = mix(p_shadow, p_crimson, smoothstep(0.0, 0.32, t));
	// Crimson → Ash
	vec3 ca2 = mix(p_crimson, p_ash, smoothstep(0.25, 0.55, t));
	// Ash → Gold
	vec3 ag = mix(p_ash, p_gold, smoothstep(0.50, 0.90, t));

	// Blend zones together
	palette_color = sc;
	palette_color = mix(palette_color, ca2, smoothstep(0.15, 0.45, t));
	palette_color = mix(palette_color, ag,  smoothstep(0.45, 0.75, t));

	// Mix palette with original desaturated color
	color = mix(color, palette_color, palette_strength);

	// ── 6. DITHERING (Halftone Grime) ───────────────────────────
	// Adds Bayer-pattern noise before any posterize — prevents
	// smooth gradients from looking too clean
	vec2 screen_pos = uv / SCREEN_PIXEL_SIZE;
	float dither = bayer4(screen_pos) - 0.5; // -0.5 → 0.5
	color += dither * dither_amount;

	// ── 7. FILM GRAIN ───────────────────────────────────────────
	// Moving noise — unifies all asset texture qualities under one gritty film
	float grain_t = floor(TIME * 16.0); // Fast flicker — film feel
	float noise = hash(uv * 1000.0 + vec2(grain_t * 0.1, grain_t * 0.17)) * 2.0 - 1.0;
	color += noise * grain_amount;

	// ── 8. SCANLINES (Retro CRT Grime) ──────────────────────────
	float scanline = sin(uv.y * scanline_count * PI) * 0.5 + 0.5;
	// Only darken, never brighten (asymmetric — feels like LCD bleed)
	scanline = pow(scanline, 2.0);
	color *= (1.0 - scanline_intensity * (1.0 - scanline));

	// ── 9. VIGNETTE (Blood-Red Edge Pressure) ───────────────────
	// The edges of the screen close in with a blood-tinted darkness
	float d = distance(uv, vec2(0.5, 0.5));
	float vig = smoothstep(1.1, 0.45, d * (1.0 + vignette_intensity));
	// Blend toward vignette_color at the darkened edges
	color = mix(vignette_color, color, vig);
	color *= vig;

	// ── 10. CLAMP & OUTPUT ──────────────────────────────────────
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}