shader_type spatial;
render_mode unshaded;

uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D roughness_tex : hint_roughness_r;
uniform bool is_stunned = false;
uniform bool is_hit = false;
uniform float hit_timer = 0.0;
uniform float stun_timer = 0.0;
uniform float hit_duration = 0.2;
uniform float stun_flash_speed = 5.0;

void fragment() {
    vec4 albedo = texture(albedo_tex, UV);
    vec3 normal = texture(normal_tex, UV).rgb * 2.0 - 1.0; // Conversion de la normal map
    float roughness = texture(roughness_tex, UV).r; // Récupère la roughness
    
    vec3 final_color = albedo.rgb;
    
    if (is_hit && hit_timer < hit_duration) {
        // Clignotement rouge pour l'impact
        float hit_factor = sin(TIME * 20.0) * 0.5 + 0.5;
        final_color = mix(final_color, vec3(1.0, 0.0, 0.0), hit_factor);
    } else if (is_stunned) {
        // Clignotement blanc pendant le stun
        float stun_factor = sin(TIME * stun_flash_speed) * 0.5 + 0.5;
        final_color = mix(final_color, vec3(1.0, 1.0, 1.0), stun_factor);
    }
    
    ALBEDO = final_color;
    NORMAL = normalize(normal);
    ROUGHNESS = roughness;
}