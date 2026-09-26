#include "common.hlsli"

RWTexture2D<float4> output_image : register(u0, space1);

cbuffer UniformBlock : register(b0, space2) {
    float2 center;
    float  zoom;
    int    max_iter;

    float4 palette_offset;
    float4 palette_amplitude;
    float4 palette_frequency;
    float4 palette_phase;

    float4 interior_color;

    float2 resolution;
    float  power;
};

[numthreads(8, 8, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    int2 pixel = int2(global_id.xy);
    if (pixel.x >= int(resolution.x) || pixel.y >= int(resolution.y)) return;

    float2 uv = (float2(pixel) - resolution * 0.5) / (resolution.y * zoom) + center;

    float2 z = float2(0.0, 0.0);
    int iter = 0;
    while (iter < max_iter && dot(z, z) < 4.0) {
        z = abs(z);
        z = complex_pow(z, power) + uv;
        iter++;
    }

    float4 color = interior_color;
    if (iter < max_iter) {
        float t = smooth_iter(iter, z, max_iter);
        color = cosine_palette(
            palette_offset,
            palette_amplitude,
            palette_frequency,
            palette_phase,
            t
        );
    }

    output_image[pixel] = float4(color.xyz, 1.0);
}