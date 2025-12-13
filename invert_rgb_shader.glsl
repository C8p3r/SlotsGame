// invert_rgb_shader.glsl

// Simply inverts the RGB color channels of the texture.
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, texture_coords);
    
    // Only affect non-transparent parts
    if (texcolor.a > 0.0) {
        // Invert RGB: 1.0 - color
        vec3 inverted_rgb = vec3(1.0, 1.0, 1.0) - texcolor.rgb;
        return vec4(inverted_rgb, texcolor.a);
    }
    
    return texcolor;
}