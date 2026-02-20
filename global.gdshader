shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- GENEL IŞIK VE RENK AYARLARI ---
uniform float brightness : hint_range(0.5, 2.0) = 1.1; // Ekranı aydınlatmak için 1.0'ın üzerine çık
uniform float contrast : hint_range(0.5, 2.0) = 1.15;  // Zıtlık
uniform float saturation : hint_range(0.0, 2.0) = 0.6; // Farklı assetlerin cırtlak renklerini kısmak için 1'in altı iyidir

// --- BÜTÜNCÜL RENK PALETİ (SİHİRLİ KISIM) ---
// Tüm oyunu bu iki renge doğru çeker. Asset uyumsuzluğunu bu yok eder.
uniform vec4 shadow_color : source_color = vec4(0.08, 0.1, 0.15, 1.0); // Gölgeler: Soğuk, tekinsiz koyu lacivert/gri
uniform vec4 highlight_color : source_color = vec4(0.9, 0.85, 0.7, 1.0); // Işıklar: Sıcak Mısır kumu / Kemik rengi
uniform float tint_blend : hint_range(0.0, 1.0) = 0.45; // Kendi renkleri ile bu temanın karışım oranı (0.0 orjinal, 1.0 tam filtre)

// --- LEN VE FİLM EFEKTLERİ ---
uniform float ca_strength : hint_range(0.0, 0.05) = 0.003; // Renk Sapması (Kromatik Aberasyon - Halüsinasyon hissi)
uniform float grain_amount : hint_range(0.0, 1.0) = 0.06;  // Film Kumlanması (Asset doku farklarını gizleyen katman)
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.3; // Kenar kararması (Çok abartılmamış)

// Kumlanma için rastgele sayı üreteci
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // 1. KROMATİK ABERASYON (Farklı modelleri aynı fiziksel kameradan çıkmış gibi gösterir)
    float r = texture(SCREEN_TEXTURE, uv + vec2(ca_strength, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - vec2(ca_strength, 0.0)).b;
    vec3 color = vec3(r, g, b);

    // 2. KONTRAST VE PARLAKLIK (Aşırı karanlık sorununu çözer)
    color = (color - 0.5) * contrast + 0.5;
    color *= brightness;

    // 3. DOYGUNLUK (Assetlerin uyumsuz, patlayan renklerini dengeler)
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(gray), color, saturation);

    // 4. BÜTÜNCÜL RENK TONLAMASI (Color Grading)
    // Ekrandaki her şeyi gölgelerde 'shadow_color', aydınlıklarda 'highlight_color' tonlarına çeker.
    vec3 tinted_color = mix(shadow_color.rgb, highlight_color.rgb, gray);
    color = mix(color, tinted_color, tint_blend);

    // 5. FİLM KUMLANMASI (Film Grain)
    // Doku kalitesi uyumsuzluklarını fiziki bir filtrenin altında eritir.
    float noise = (hash(uv * TIME) * 2.0 - 1.0); // Sürekli hareket eden karıncalanma
    color += noise * grain_amount;

    // 6. VIGNETTE (Odağı merkeze çeker, ekranın çok küçük bir kısmını usulca karartır)
    float d = distance(uv, vec2(0.5, 0.5));
    float vignette = smoothstep(1.2, 0.5, d * (1.0 + vignette_intensity));
    color *= vignette;

    COLOR = vec4(color, 1.0);
}