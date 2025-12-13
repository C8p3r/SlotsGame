// scanline_shader.glsl

extern float scanline_density; // e.g., 500.0

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, texture_coords);
    
    // Only affect non-transparent parts
    if (texcolor.a < 0.1) {
        return texcolor;
    }
    
    // Calculate the normalized Y coordinate within the game resolution
    float y_pos = screen_coords.y;

    // FIX: Use the external uniform scanline_density 
    float density_factor = scanline_density; 
    
    // Determine the position in the scanline pattern
    float scanline_pattern = mod(y_pos * density_factor, 1.0);

    // This controls how dark the scanline gets (0.8 is very dark)
    float scanline_dimming_factor = 0.8; 
    
    // Create the dimming effect: lines are sharp and dark
    // smoothstep(0.3, 0.7, ...) creates a wide, bold line
    float dimming = 1.0 - scanline_dimming_factor * smoothstep(0.3, 0.7, scanline_pattern);
    
    // Apply dimming to the final color
    vec3 final_color = texcolor.rgb * dimming;
    
    // Optional CRT curved border/vignette effect (subtle)
    vec2 uv = screen_coords.xy / 1400.0; // Normalized to game width
    vec2 center = vec2(0.5);
    float d = distance(uv, center);
    float vignette = 1.0 - d * d * 0.5; // Simple radial dimming

    final_color *= vignette;
    
    return vec4(final_color, texcolor.a);
}