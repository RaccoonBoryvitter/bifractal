Texture2D    u_texture : register(t0, space2);
SamplerState u_sampler : register(s0, space2);

struct PSInput {
    float2 v_uv    : TEXCOORD0;
    float4 v_color : COLOR1;
};

float4 main(PSInput input) : SV_Target0 {
    return input.v_color * u_texture.Sample(u_sampler, input.v_uv);
}