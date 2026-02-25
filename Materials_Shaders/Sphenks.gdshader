shader_type canvas_item;

// --- GODOT 4 DÜZELTMESİ ---
// SCREEN_TEXTURE artık otomatik gelmiyor, biz tanımlıyoruz:
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 1.0) = 0.0; // Varsayılan SIFIR olsun
uniform float speed : hint_range(0.0, 10.0) = 5.0;   // Dalga hızı

void fragment() {
    vec2 uv = SCREEN_UV;

    // Dalgalanma Formülü
    uv.x += sin(uv.y * 10.0 + TIME * speed) * strength;
    uv.y += cos(uv.x * 10.0 + TIME * speed) * strength;

    // texture() fonksiyonu artık tanımladğimiz SCREEN_TEXTURE'u kullanıyor
    vec4 color = texture(SCREEN_TEXTURE, uv);

    // Renk Ayrışması (Kromatik Aberasyon - Kafa yapıcı etki)
    float r = texture(SCREEN_TEXTURE, uv + vec2(strength * 0.5, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - vec2(strength * 0.5, 0.0)).b;

    COLOR = vec4(r, g, b, 1.0);
}