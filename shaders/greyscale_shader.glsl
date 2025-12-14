// greyscale_shader.glsl

// Desaturates and optionally blurs the input using luminance
uniform vec2 texSize;    // size of the texture/canvas in pixels
uniform float blurRadius; // blur radius in pixels (0 = no blur)
uniform float desat;     // desaturation amount [0..1]

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 px = 1.0 / texSize;

    // 9-sample box/approx blur (center + 8 neighbors) scaled by blurRadius
    vec2 offsets[9];
    offsets[0] = vec2(0.0, 0.0);
    offsets[1] = vec2(1.0, 0.0);
    offsets[2] = vec2(-1.0, 0.0);
    offsets[3] = vec2(0.0, 1.0);
    offsets[4] = vec2(0.0, -1.0);
    offsets[5] = vec2(1.0, 1.0);
    offsets[6] = vec2(-1.0, 1.0);
    offsets[7] = vec2(1.0, -1.0);
    offsets[8] = vec2(-1.0, -1.0);

    vec3 accum = vec3(0.0);
    float total = 0.0;
    for (int i = 0; i < 9; i++) {
        vec2 o = offsets[i] * blurRadius * px;
        vec4 t = Texel(texture, uv + o) * color;
        accum += t.rgb;
        total += 1.0;
    }

    vec3 col = accum / total;
    float grey = dot(col, vec3(0.299, 0.587, 0.114));

    // Mix original color with greyscale according to `desat`
    float d = clamp(desat, 0.0, 1.0);
    vec3 outc = mix(col, vec3(grey), d);

    float a = Texel(texture, uv).a * color.a;
    return vec4(outc, a);
}
