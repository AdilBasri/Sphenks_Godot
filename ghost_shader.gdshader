shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Orjinal ekran rengini al
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    // Gri tonunu hesapla (luminance)
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Yüksek kontrast oluştur
    float contrast = 1.5;
    gray = (gray - 0.5) * contrast + 0.5;
    
    // Siyah beyaz rengi oluştur
    vec3 bw_color = vec3(gray);
    
    // İstediğimiz yoğunluğa göre orjinal renk ile karıştır
    COLOR.rgb = mix(color.rgb, bw_color, intensity);
    COLOR.a = color.a;
}
