#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, set = 1, binding = 0) uniform writeonly image2D output_image;

layout(std140, set = 2, binding = 0) uniform UniformBlock {
    vec2 center;
    float zoom;
    int max_iter;

    vec3 palette_a;
    vec3 palette_b;
    vec3 palette_c;
    vec3 palette_d;

    vec2 resolution;
};

const float TWO_PI = 6.28318;

vec3 cosine_palette(float t) {
    return palette_a + palette_b * cos(TWO_PI * (palette_c * t + palette_d));
}

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (pixel.x >= int(resolution.x) || pixel.y >= int(resolution.y)) return;

    vec2 uv = (vec2(pixel) - resolution * 0.5) / (resolution.y * zoom) + center;

    vec2 z = vec2(0.0);
    int iter = 0;
    while (iter < max_iter && dot(z, z) < 4.0) {
        z = vec2(z.x * z.x - z.y * z.y + uv.x, 2.0 * z.x * z.y + uv.y);
        iter++;
    }

    vec3 color = vec3(0.0);
    if (iter < max_iter) {
        float smooth_iter = float(iter) - log2(log2(dot(z, z))) + 4.0;
        float t = smooth_iter / float(max_iter);
        // float t = float(iter) / float(max_iter);
        color = cosine_palette(t);
    }

    imageStore(output_image, pixel, vec4(color, 1.0));
}