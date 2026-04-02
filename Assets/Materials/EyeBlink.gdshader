shader_type canvas_item;

uniform float blink_amount : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.1;
uniform vec4 eye_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// Shift UV towards the center to create a simple fisheye distortion
	vec2 center = vec2(0.5, 0.5);
	vec2 diff = uv - center;
	float dist_sq = dot(diff, diff);
	uv = uv + diff * dist_sq * distortion_strength;
	
	// Create blink eyelids (top and bottom curves)
	float y = uv.y;
	
	// Calculate curve amount based on distance from center X
	float curve = (uv.x - 0.5) * (uv.x - 0.5) * 4.0;
	// When blink_amount is 1.0, lids cover the whole screen. When 0.0, they are pushed away.
	float top_lid = (blink_amount * 1.5) - curve - 0.2;
	float bottom_lid = 1.0 + (curve + 0.2) - (blink_amount * 1.5);
	
	if (y < top_lid || y > bottom_lid) {
		COLOR = eye_color;
	} else {
		// Just render screen underneath, maybe with slight blur or overlay?
		COLOR = texture(TEXTURE, UV); // We will pass a transparent texture or SCREEN_TEXTURE
		// Since we use transparent color rect, we'll just alpha to 0 for center
		COLOR.a = 0.0;
	}
}
