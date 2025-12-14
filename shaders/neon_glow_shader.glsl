// neon_glow_shader.glsl

extern float time;
extern vec2 resolution;
extern float intensity; 

// Simple pseudo-random noise (required if LOVE2D noise functions aren't directly available in GLSL 120, though love provides a noise uniform)
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Value Noise for organic flicker
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
    vec4 base_color = Texel(texture, texture_coords); 

    // Return transparent pixels immediately
    if (base_color.a < 0.1) {
        return base_color;
    }
    
    // --- 1. Calculate Flicker/Pulse ---
    
    // Fast noise component for flicker
    float flicker_noise = noise(screen_coords.xy * 0.005 + time * 30.0);
    
    // Slow pulse component for breathing effect
    float slow_pulse = 1.0 + 0.1 * sin(time * 5.0);
    
    // Combine noise and pulse, clamp to a useful range (e.g., 0.8 to 1.2)
    float flicker_factor = clamp(slow_pulse + (flicker_noise * 0.3), 0.8, 1.2);
    
    // --- 2. Calculate Blur/Glow ---

    vec3 glow_sum = base_color.rgb;
    
    // Blur loop - sample around the pixel
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            // Apply flicker to blur spread, making the glow unstable
            vec2 sample_coord = texture_coords + vec2(float(i), float(j)) * 0.005 * intensity * flicker_factor;
            glow_sum += Texel(texture, sample_coord).rgb * 0.2; 
        }
    }
    
    // Apply final intensity and flicker
    vec3 final_glow = mix(base_color.rgb, glow_sum * 0.4 * flicker_factor, 0.5 + intensity * 0.5);

    return vec4(final_glow, base_color.a);
}