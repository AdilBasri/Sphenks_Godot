shader_type canvas_item;

uniform vec4 renk : source_color = vec4(0.1, 0.0, 0.0, 0.8); // Koyu kırmızımsı
uniform float hiz = 0.2;

float random (vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    float gurutu = random(UV + TIME * hiz);
    COLOR = renk * vec4(vec3(gurutu), 1.0);
}