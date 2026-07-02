RWTexture2D<float4> output_image : register(u0, space1);

cbuffer UniformBlock : register(b0, space2) {
    float2 center;
    float  zoom;
    int    max_iter;

    float4 palette_a;
    float4 palette_b;
    float4 palette_c;
    float4 palette_d;

    float2 resolution;
};
    
static const float TWO_PI = 6.28318;

float4 cosine_palette(float t) {
    return palette_a + palette_b * cos(TWO_PI * (palette_c * t + palette_d));
}

[numthreads(8, 8, 1)]
void main(uint3 global_id : SV_DispatchThreadID) {
    int2 pixel = int2(global_id.xy);
    if (pixel.x >= int(resolution.x) || pixel.y >= int(resolution.y)) return;

    float2 uv = (float2(pixel) - resolution * 0.5) / (resolution.y * zoom) + center;

    float2 z = float2(0.0, 0.0);
    int iter = 0;
    while (iter < max_iter && dot(z, z) < 4.0) {
        z = float2(z.x * z.x - z.y * z.y + uv.x, 2.0 * z.x * z.y + uv.y);
        iter++;
    }

    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    if (iter < max_iter) {
        float smooth_iter = float(iter) - log2(log2(dot(z, z))) + 4.0;
        float t = smooth_iter / float(max_iter);
        color = cosine_palette(t);
    }

    output_image[pixel] = float4(color.xyz, 1.0);
}