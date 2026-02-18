shader_type spatial;
render_mode blend_mix, cull_back, unshaded;

// === MİDE SIVI DOLDURMA SHADER ===
// fill_amount: 0.0 (boş) → 1.0 (dolu)
// liquid_color: sıvı rengi (koyu kan kırmızısı varsayılan)
// wobble: oyuncu hareket vektörü → sloshing efekti
// wall_color: mide duvarı rengi (üst kısım — boş alan)

group_uniforms fill;
uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform float fill_edge_softness : hint_range(0.001, 0.15) = 0.03;

group_uniforms liquid;
uniform vec4 liquid_color : source_color = vec4(0.4, 0.02, 0.02, 1.0);
uniform vec4 liquid_highlight : source_color = vec4(0.7, 0.1, 0.05, 1.0);
uniform float liquid_fresnel_power : hint_range(0.5, 8.0) = 3.0;

group_uniforms wall;
uniform vec4 wall_color : source_color = vec4(0.15, 0.06, 0.06, 0.6);
uniform float wall_fresnel_power : hint_range(0.5, 8.0) = 2.0;

group_uniforms wobble;
uniform vec3 wobble = vec3(0.0);
uniform float wobble_intensity : hint_range(0.0, 0.3) = 0.08;
uniform float wave_speed : hint_range(0.5, 10.0) = 3.0;
uniform float wave_scale : hint_range(1.0, 20.0) = 6.0;

// İç değişkenler (varyings)
varying float world_y_normalized;
varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
    // Dünya pozisyonunu hesapla
    vec4 world_vertex = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_pos = world_vertex.xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

    // Mesh'in Y eksenini 0-1 arasında normalize et
    // (mesh'in local y: -0.5 → +0.5 varsayım, SphereMesh/CapsuleMesh uyumlu)
    float local_y = VERTEX.y;
    world_y_normalized = (local_y + 0.5); // 0 = alt, 1 = üst

    // --- SIVI SLOSHING (Vertex Displacement) ---
    // Wobble vektörü (oyuncu hızı) ile dalga efekti
    float wobble_amount = length(wobble) * wobble_intensity;
    if (wobble_amount > 0.001) {
        // Sıvı hattı yakınında dalga oluştur
        float proximity_to_surface = 1.0 - abs(world_y_normalized - fill_amount) * 4.0;
        proximity_to_surface = clamp(proximity_to_surface, 0.0, 1.0);

        // Dalga formülü — wobble yönüne bağlı
        float wave = sin(VERTEX.x * wave_scale + TIME * wave_speed + wobble.x * 5.0) *
                     cos(VERTEX.z * wave_scale + TIME * wave_speed * 0.7 + wobble.z * 5.0);

        VERTEX.y += wave * wobble_amount * proximity_to_surface * 0.15;
    }

    // Sıvı bölgesinde hafif "şişme" efekti
    if (world_y_normalized < fill_amount) {
        float bulge = sin(world_y_normalized * 3.14159) * 0.03 * fill_amount;
        VERTEX.xyz += NORMAL * bulge;
    }
}

void fragment() {
    // --- FILL LINE HESAPLAMA ---
    // Wobble ile hattı hafif sallandır
    float wobble_offset = sin(world_pos.x * wave_scale + TIME * wave_speed) *
                          cos(world_pos.z * wave_scale * 0.8 + TIME * wave_speed * 0.6) *
                          length(wobble) * wobble_intensity * 0.5;

    float fill_line = fill_amount + wobble_offset;

    // Keskin sıvı hattı (smoothstep ile yumuşak kenar)
    float is_liquid = smoothstep(fill_line + fill_edge_softness, fill_line - fill_edge_softness, world_y_normalized);

    // --- FRESNEL ---
    float fresnel = pow(1.0 - abs(dot(world_normal, normalize(VIEW))), liquid_fresnel_power);
    float wall_fresnel = pow(1.0 - abs(dot(world_normal, normalize(VIEW))), wall_fresnel_power);

    // --- SIVI RENGİ ---
    // Fresnel ile parlama
    vec3 liq_color = mix(liquid_color.rgb, liquid_highlight.rgb, fresnel * 0.6);
    // Hafif dalga deseni
    float wave_pattern = sin(world_pos.x * 15.0 + TIME * 2.0) *
                         sin(world_pos.z * 15.0 + TIME * 1.5) * 0.1 + 0.9;
    liq_color *= wave_pattern;

    // --- DUVAR RENGİ (Boş kısım) ---
    vec3 w_color = wall_color.rgb + wall_fresnel * 0.15;

    // --- KARİŞTİR ---
    vec3 final_color = mix(w_color, liq_color, is_liquid);

    // Alpha: sıvı kısmı opak, duvar kısmı yarı saydam
    float final_alpha = mix(wall_color.a, 1.0, is_liquid);

    // Sıvı hattında parlak kenar (meniscus efekti)
    float edge_glow = smoothstep(0.02, 0.0, abs(world_y_normalized - fill_line)) * fill_amount;
    final_color += liquid_highlight.rgb * edge_glow * 0.5;

    ALBEDO = final_color;
    ALPHA = final_alpha;
}
