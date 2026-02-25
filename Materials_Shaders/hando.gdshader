shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// --- DOKU (RESİM) AYARI ---
uniform sampler2D et_dokusu : source_color;

// --- SALLANMA AYARLARI ---
uniform float sallanma_hizi : hint_range(0.0, 10.0) = 3.0;
uniform float sallanma_genisligi : hint_range(0.0, 0.5) = 0.15;
uniform float dalga_sikligi : hint_range(0.0, 5.0) = 2.0;
uniform int ana_eksen : hint_range(0, 2) = 2; 

void vertex() {
    vec3 pos = VERTEX;
    float t = TIME * sallanma_hizi;
    float uzama_mesafesi = 0.0;
    
    if (ana_eksen == 0) { uzama_mesafesi = pos.x; }
    else if (ana_eksen == 1) { uzama_mesafesi = pos.y; }
    else { uzama_mesafesi = pos.z; }

    float etki_maskesi = pow(max(0.0, uzama_mesafesi), 1.5);

    float x_offset = sin(t + uzama_mesafesi * dalga_sikligi) * sallanma_genisligi * etki_maskesi;
    float y_offset = cos(t + uzama_mesafesi * dalga_sikligi * 0.7) * sallanma_genisligi * etki_maskesi;
    
    if (ana_eksen == 2) {
        VERTEX.x += x_offset;
        VERTEX.y += y_offset;
    } else if (ana_eksen == 1) {
        VERTEX.x += x_offset;
        VERTEX.z += y_offset;
    } else {
        VERTEX.y += x_offset;
        VERTEX.z += y_offset;
    }
}

void fragment() {
    // Meshy'den gelen resmi modele giydiriyoruz
    vec4 resim_rengi = texture(et_dokusu, UV);
    ALBEDO = resim_rengi.rgb;
}