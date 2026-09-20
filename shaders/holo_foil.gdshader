shader_type canvas_item;

uniform bool is_active = false;
uniform float tilt_x = 0.0;
uniform float tilt_y = 0.0;
uniform float shine_intensity = 0.65;

vec3 rainbow(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
    vec4 base_col = texture(TEXTURE, UV);
    if (!is_active) {
        COLOR = base_col;
    } else {
        // Calcola gradiente olografico basato sulla posizione UV e l'inclinazione
        float angle_shift = (UV.x * 1.5 + UV.y * 0.8) + (tilt_x + tilt_y) * 0.05;
        vec3 holo = rainbow(angle_shift);

        // Luce speculare diagonale che scorre inclinando la carta
        float glint = smoothstep(0.4, 0.6, sin(angle_shift * 6.28318 + tilt_x * 0.1));
        vec3 final_rgb = mix(base_col.rgb, holo, 0.35) + vec3(glint * shine_intensity);
        COLOR = vec4(final_rgb, base_col.a);
    }
}
