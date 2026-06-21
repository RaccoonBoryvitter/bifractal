cbuffer Globals : register(b0, space1) {
    float2 screen_size;
};

struct VSInput {
    float2 a_position : TEXCOORD0;
    float2 a_uv       : TEXCOORD1;
    float4 a_color    : TEXCOORD2;
};

struct VSOutput {
    float2 v_uv    : TEXCOORD0;
    float4 v_color : COLOR1;
    float4 pos     : SV_Position;
};

VSOutput main(VSInput input) {
    VSOutput output;
    output.v_uv    = input.a_uv;
    output.v_color = input.a_color;
    output.pos     = float4(
        (input.a_position.x / screen_size.x) * 2.0 - 1.0,
        -((input.a_position.y / screen_size.y) * 2.0 - 1.0),
        0.0, 1.0
    );
    return output;
}