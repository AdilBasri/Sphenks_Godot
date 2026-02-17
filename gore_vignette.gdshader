shader_type canvas_item;

// Vignette / Gore Pulse Shader
// Ekranın kenarlarını karartır, kırmızı/siyah nabız atar.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.5, 10.0) = 3.0;
uniform float vignette_radius : hint_range(0.1, 1.0) = 0.45;
uniform float vignette_softness : hint_range(0.01, 0.5) = 0.25;

void fragment() {
    // --- VIGNETTE ---
    vec2 center = UV - vec2(0.5);
    float dist = length(center);

    // Kenarlardan merkeze doğru yumuşak karartma
    float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);

    // --- KAN NABZI ---
    // Sinüs ile ritmik nabız (chewing/tearing simülasyonu)
    float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
    float blood_pulse = pulse * 0.4; // Nabız şiddeti

    // Kan kırmızısı + karanlık karışımı
    vec3 blood_color = vec3(0.35, 0.02, 0.02); // Koyu kan kırmızısı
    vec3 dark_color = vec3(0.0, 0.0, 0.0);     // Saf karanlık

    // Nabızla renk geçişi: siyah <-> koyu kırmızı
    vec3 final_color = mix(dark_color, blood_color, blood_pulse);

    // Vignette maskesi + intensity kontrolü
    float alpha = vignette * intensity;

    // Ekstra: nabız anında hafif parlama (daha visceral)
    alpha += blood_pulse * 0.15 * intensity;
    alpha = clamp(alpha, 0.0, 0.92); // Tam siyah olmasın, biraz görünsün

    COLOR = vec4(final_color, alpha);
}
