// pixelate_shader.glsl

uniform vec2 texSize;
uniform float pixelSize; // pixel size in pixels

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 px = texSize;
    // Compute the center of the pixel block
    vec2 coord = floor(uv * px / pixelSize) * pixelSize + pixelSize * 0.5;
    vec2 sampleUV = coord / px;
    vec4 c = Texel(texture, sampleUV) * color;
    return c;
}
