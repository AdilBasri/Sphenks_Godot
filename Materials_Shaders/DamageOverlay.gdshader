shader_type canvas_item;

// === UNIFORMS ===
// health_ratio: 1.0 = tam can (temiz ekran), 0.0 = ölüm eşiği (iğrenç ekran)
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
// Damar dokusu (vein.png) — beyaz kısımlar = şeffaf, siyah kısımlar = damar
uniform sampler2D vein_texture : source_color;

// === RENK PALETİ ===
uniform vec4 color_black  : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform vec4 color_blue   : source_color = vec4(0.08, 0.05, 0.35, 1.0);
uniform vec4 color_red    : source_color = vec4(0.85, 0.05, 0.02, 1.0);

void fragment() {
    COLOR = color_red;
    COLOR.a = 0.5;
}
