// ============================================================
//   OUTLINE HULL — Graphic Novel Silhouette Shader
//   Sphenks Godot Horror Game
// ============================================================
//   METHOD: Inverted Hull (Industry Standard for 3D Outlines)
//   — Renders ONLY back faces (cull_front)
//   — Expands each vertex along its normal in clip space
//   — Result: a solid colored shell visible only around the
//     silhouette of the mesh from the outside
//
//   HOW TO APPLY TO ANY 3D MODEL:
//   ─────────────────────────────────────────────────────────
//   1. Select a MeshInstance3D (Anubis, weapon, mummy, etc.)
//   2. In the Inspector, find the mesh's Surface Material slot
//      (Surface Material Override → Surface 0)
//   3. Click the material → bottom of material → "Next Pass"
//      Click the empty slot and choose "New ShaderMaterial"
//   4. On the new ShaderMaterial → Shader → "Load"
//      Navigate to: res://outline_hull.gdshader
//   5. Tweak "outline_width" to taste:
//        Characters : ~0.006 – 0.010
//        Weapons    : ~0.003 – 0.005
//        Small props: ~0.002 – 0.004
//   6. Set "outline_color" — default is near-black blood void
//      For a dark-red cult variant use: vec4(0.25, 0.0, 0.0, 1.0)
//
//   TIP: This shader has ZERO cost on the base material pass.
//   It only draws a thin extra shell. Very GPU-friendly.
// ============================================================

shader_type spatial;

// The key: only back faces are rendered.
// From the camera's perspective, these back-face polygons peek
// out from behind the silhouette as the outline.
render_mode cull_front, unshaded, depth_draw_always;

// ─── UNIFORMS ─────────────────────────────────────────────────
// Width of the outline in clip space units.
// Larger values = thicker outline. Watch for mesh self-intersection.
uniform float outline_width : hint_range(0.0, 0.05) = 0.007;

// The outline color. Default = near-black void with a blood tinge.
// Try vec4(0.22, 0.0, 0.0, 1.0) for dark crimson variant.
uniform vec4 outline_color : source_color = vec4(0.04, 0.0, 0.0, 1.0);

// Distance fade: outline gets thinner with distance so distant
// objects don't get giant thick outlines (perspective correction).
// 0.0 = no fade (constant width), 1.0 = full perspective scaling
uniform float distance_fade : hint_range(0.0, 1.0) = 0.75;

// Flicker: a subtle, low-frequency pulse on the outline width
// makes it feel hand-drawn / inked — like a trembling brush
uniform float ink_flicker : hint_range(0.0, 1.0) = 0.12;


void vertex() {
	// ── Step 1: Transform normal to clip space ─────────────────
	// We need the normal direction in clip (screen) space so the
	// outline has uniform pixel thickness regardless of geometry angle.

	// View-space normal
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Clip-space position of the vertex
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));

	// Project the normal to screen space (ndc normal)
	// Divide by clip_pos.w to convert to NDC proportions
	vec2 screen_normal = normalize(
		(PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy
	);

	// ── Step 2: Calculate width ────────────────────────────────
	float width = outline_width;

	// Distance fade: scale down width by depth so distant objects
	// don't get fat outlines (mimics how ink lines behave in print)
	float depth = clip_pos.w; // .w = depth in clip space
	width *= mix(1.0, 1.0 / max(depth * 0.15, 0.1), distance_fade);

	// Ink flicker: subtle time-based pulsation for a hand-drawn feel
	float flicker = 1.0 + sin(TIME * 7.3 + VERTEX.x * 13.1 + VERTEX.y * 9.7) * ink_flicker * 0.5;
	width *= flicker;

	// ── Step 3: Expand vertex along screen-space normal ─────────
	// This is the core inverted hull trick:
	// push the vertex along its screen-normal direction, in clip space.
	// Aspect ratio correction prevents oval outlines on non-square screens.
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	clip_pos.xy += screen_normal * width * vec2(1.0, aspect);

	// ── Step 4: Output ──────────────────────────────────────────
	POSITION = clip_pos;
}


void fragment() {
	// Pure solid color — no lighting calculation whatsoever.
	// The outline is always the same flat tone.
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
