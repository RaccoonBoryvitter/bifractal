static const float TWO_PI = 6.28318;

float4 cosine_palette(float4 offset, float4 amplitude, float4 frequency, float4 phase, float t) {
    return offset + amplitude * cos(TWO_PI * (frequency * t + phase));
}

float smooth_iter(int iter, float2 z, int max_iter) {
    return (float(iter) - log2(log2(dot(z, z))) + 4.0) / float(max_iter);
}