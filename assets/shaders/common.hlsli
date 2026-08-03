static const float TWO_PI = 6.28318;

float4 cosine_palette(float4 offset, float4 amplitude, float4 frequency, float4 phase, float t) {
    return offset + amplitude * cos(TWO_PI * (frequency * t + phase));
}

float smooth_iter(int iter, float2 z, int max_iter) {
    return (float(iter) - log2(log2(dot(z, z))) + 4.0) / float(max_iter);
}

float2 complex_pow(float2 z, float d) {
    float r2 = dot(z, z);
    if (r2 < 1e-24) return float2(0.0, 0.0); // avoid atan2(0,0)/log(0) issues near origin
    float theta = atan2(z.y, z.x);
    float r_d = pow(r2, d * 0.5);
    float sin_td, cos_td;
    sincos(d * theta, sin_td, cos_td);
    return r_d * float2(cos_td, sin_td);
}
