// background_shader.glsl

extern float time;      // Scaled time, controls speed and animation
extern vec2 resolution; 

// --- NOISE FUNCTIONS ---
// Hash function for pseudo-random numbers
float hash(float n) { return fract(sin(n) * 43758.5453); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(15.79, 93.85))) * 43758.5453); }

// Standard Value Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Fractional Brownian Motion (FBM) for complex turbulence
float fbm(vec2 p) {
    float f = 0.0;
    f += 0.5000 * noise(p); p *= 2.02;
    f += 0.2500 * noise(p); p *= 2.03;
    f += 0.1250 * noise(p); p *= 2.01;
    f += 0.0625 * noise(p);
    return f;
}

// HSL (Hue, Saturation, Lightness) to RGB Conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
// -----------------------

// Shader entry point
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = screen_coords.xy / resolution.xy;
    
    // 1. Create Swirling Displacements (Simulated Fluid Flow)
    // Add time component to simulate continuous movement
    vec2 p = uv * 3.0; // Base scale of the noise field
    
    // Displace UVs using FBM for swirling effect
    vec2 displacement = vec2(
        fbm(p + vec2(time * 0.1, time * 0.05)),
        fbm(p + vec2(time * -0.05, time * 0.1))
    );
    
    // The core turbulence pattern
    float turb = fbm(p + displacement * 2.0);

    // 2. Map Turbulence to Color and Lightness
    
    // Hue: Rotate the hue based on the turbulence magnitude and time
    float hue = mod(turb * 0.8 + time * 0.05, 1.0);
    
    // Saturation: High saturation for the iridescent effect
    float sat = 0.95; 
    
    // Lightness: Create high contrast spots for depth and shimmer
    // Use turb squared for sharp highlights, combined with a sine wave for shimmer
    float lightness_mod = pow(turb, 2.5); 
    float shimmer = 0.1 * sin(turb * 50.0 + time * 5.0); // Fast shimmering component
    
    float lightness = 0.1 + lightness_mod * 0.2 + shimmer;
    
    vec3 hsv = vec3(
        hue,         
        sat,         
        lightness
    );
    
    vec3 final_color = hsv2rgb(hsv);
    
    // Use a slight mask on the edges for a contained look (subtle vignette)
    vec2 center_uv = uv - 0.5;
    float border_mask = 1.0 - pow(length(center_uv * 1.5), 2.0);
    
    return vec4(final_color * border_mask, 1.0);
}