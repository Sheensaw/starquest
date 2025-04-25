shader_type spatial;
render_mode unshaded;

uniform vec4 core_color = vec4(1.0, 1.0, 1.0, 1.0);   // Couleur du noyau (blanc brillant)
uniform vec4 glow_color = vec4(0.0, 1.0, 0.0, 1.0);   // Couleur de la lueur (rouge)
uniform float intensity = 10.0;  // Intensité globale de la lueur
uniform float core_width = 0.1; // Largeur du noyau blanc
uniform float glow_width = 0.4; // Largeur de la lueur rouge (plus large que le noyau)

void fragment() {
    vec2 uv = UV - 0.5;  // Centrer les coordonnées UV
    float dist = length(uv);  // Distance du centre

    // Dégradé pour la lueur rouge (plus large)
    float glow_alpha = smoothstep(glow_width, 0.0, dist);
    
    // Dégradé pour le noyau blanc (plus étroit)
    float core_alpha = smoothstep(core_width, -0.2, dist);
    
    // Mélanger les couleurs
    vec3 final_color = mix(glow_color.rgb, core_color.rgb, core_alpha);
    
    // Appliquer l'intensité et l'alpha
    final_color *= intensity * glow_alpha;
    
    ALBEDO = final_color;
    ALPHA = glow_alpha;
}