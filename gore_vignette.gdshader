shader_type canvas_item;

// === GORE FRENZY VIGNETTE ===
// Intensity: genel efekt gücü (0=kapalı, 1=tam)
// Frenzy: yeme ilerledikçe artar → daha koyu, daha kırmızı, daha yoğun nabız
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float frenzy : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.5, 15.0) = 4.0;
uniform float vignette_radius : hint_range(0.05, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.01, 0.5) = 0.2;

void fragment() {
    vec2 center = UV - vec2(0.5);
    float dist = length(center);

    // Frenzy arttıkça vignette daralsın (tünel vizyonu)
    float dynamic_radius = vignette_radius - frenzy * 0.2;
    float dynamic_softness = vignette_softness - frenzy * 0.08;
    float vignette = smoothstep(dynamic_radius, dynamic_radius + dynamic_softness, dist);

    // Nabız — frenzy arttıkça daha hızlı ve sert
    float effective_speed = pulse_speed + frenzy * 8.0;
    float raw_pulse = sin(TIME * effective_speed);
    // Nabzı daha "keskin" yap (kare dalga hissi)
    float pulse = 0.5 + 0.5 * sign(raw_pulse) * pow(abs(raw_pulse), 0.4);

    // Renk paleti — frenzy ile değişim
    vec3 blood_dark = vec3(0.25, 0.0, 0.0);   // Yoğun koyu kan
    vec3 blood_bright = vec3(0.6, 0.03, 0.03); // Parlak kan kırmızısı
    vec3 void_black = vec3(0.0, 0.0, 0.0);

    // Frenzy düşükken koyu siyah, yüksekken parlak kırmızı nabız
    vec3 base_color = mix(void_black, blood_dark, frenzy);
    vec3 pulse_color = mix(blood_dark, blood_bright, frenzy);
    vec3 final_color = mix(base_color, pulse_color, pulse * frenzy);

    // Alpha — kenarlar + frenzy ile merkeze de yayılır
    float edge_alpha = vignette * intensity;
    float frenzy_flood = frenzy * 0.3 * pulse * intensity; // Merkezde de kırmızı baskı
    float alpha = clamp(edge_alpha + frenzy_flood, 0.0, 0.95);

    COLOR = vec4(final_color, alpha);
}
