shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float time_speed : hint_range(0.1, 20.0) = 15.0;

float rand(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    float t = TIME * time_speed;
    vec2 p = UV;
    
    // Add horizontal glitch bands
    float block = floor(p.y * 30.0);
    float offset = rand(vec2(block, floor(t))) * 2.0 - 1.0;
    
    if (rand(vec2(block, floor(t + 0.1))) < 0.2 * glitch_intensity) {
        p.x += offset * 0.1 * glitch_intensity;
    }
    
    // Chromatic aberration
    float r = texture(TEXTURE, p + vec2(0.02 * glitch_intensity, 0.0)).r;
    float g = texture(TEXTURE, p).g;
    float b = texture(TEXTURE, p - vec2(0.02 * glitch_intensity, 0.0)).b;
    float a = texture(TEXTURE, p).a;
    
    COLOR = vec4(r, g, b, a);
    
    // Sometimes invert colors or add noise
    if (rand(vec2(floor(t * 10.0), 0.0)) < 0.1 * glitch_intensity) {
        COLOR.rgb = vec3(1.0) - COLOR.rgb;
    }
}
