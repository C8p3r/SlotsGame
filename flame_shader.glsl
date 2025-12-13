extern float time;
extern float intensity; // 0.0 to 1.0 (or higher for crazier flames)

// Simple pseudo-random noise
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Value Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Center UVs to -0.5 to 0.5
    vec2 uv = texture_coords - 0.5;
    
    // Distance from center
    float dist = length(uv);
    
    // Create upward moving noise
    // We layer two octaves of noise for detail
    float n1 = noise(uv * 8.0 - vec2(0.0, time * 2.0));
    float n2 = noise(uv * 16.0 - vec2(0.0, time * 4.0));
    float combined_noise = (n1 + n2 * 0.5);
    
    // Distort the circle shape with noise
    // The distortion amount increases with 'intensity'
    float shape_edge = 0.35 + (combined_noise * 0.1 * intensity);
    
    // Soft edge mask
    float alpha = 1.0 - smoothstep(shape_edge - 0.05, shape_edge + 0.1, dist);
    
    // Color Palette mapping
    // Core is white/yellow, mid is orange/red, edge is dark
    // We use the noise + distance to pick color
    float heat = (1.0 - dist * 2.5) + (combined_noise * 0.5 * intensity);
    
    vec3 col = vec3(0.0);
    if (heat > 0.8) col = vec3(1.0, 1.0, 0.8);       // White/Yellow Hot
    else if (heat > 0.5) col = vec3(1.0, 0.6, 0.1);  // Orange
    else if (heat > 0.2) col = vec3(0.8, 0.1, 0.0);  // Red
    else col = vec3(0.1, 0.0, 0.0);                  // Dark Char
    
    // Output final color
    // Scale opacity by intensity so low streaks are fainter
    return vec4(col, alpha * min(1.0, 0.5 + intensity * 0.5));
}