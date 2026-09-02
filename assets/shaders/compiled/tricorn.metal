#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct type_UniformBlock
{
    float2 center_hi;
    float2 center_lo;
    float zoom;
    packed_float2 _pad;
    int max_iter;
    float4 palette_offset;
    float4 palette_amplitude;
    float4 palette_frequency;
    float4 palette_phase;
    float4 interior_color;
    float2 resolution;
    float power;
};

kernel void main0(constant type_UniformBlock& UniformBlock [[buffer(0)]], texture2d<float, access::write> output_image [[texture(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    do
    {
        int2 _52 = int2(gl_GlobalInvocationID.xy);
        bool _66;
        if (_52.x < int(UniformBlock.resolution.x))
        {
            _66 = _52.y >= int(UniformBlock.resolution.y);
        }
        else
        {
            _66 = true;
        }
        if (_66)
        {
            break;
        }
        float2 _85 = ((float2(_52) - (UniformBlock.resolution * 0.5)) / float2(UniformBlock.resolution.y * UniformBlock.zoom)) + (UniformBlock.center_hi + UniformBlock.center_lo);
        float2 _87;
        int _90;
        _87 = float2(0.0);
        _90 = 0;
        float2 _88;
        int _91;
        int _95;
        bool _96;
        for (;;)
        {
            _95 = UniformBlock.max_iter;
            _96 = _90 < _95;
            bool _101;
            if (_96)
            {
                _101 = dot(_87, _87) < 4.0;
            }
            else
            {
                _101 = false;
            }
            if (_101)
            {
                float _104 = -_87.y;
                float2 _105 = _87;
                _105.y = _104;
                float2 _123;
                do
                {
                    float _110 = dot(_105, _105);
                    if (_110 < 1.0000000195414813782625560981111e-24)
                    {
                        _123 = float2(0.0);
                        break;
                    }
                    float _118 = UniformBlock.power * precise::atan2(_104, _87.x);
                    _123 = float2(cos(_118), sin(_118)) * powr(_110, UniformBlock.power * 0.5);
                    break;
                } while(false);
                _88 = _123 + _85;
                _91 = _90 + 1;
                _87 = _88;
                _90 = _91;
                continue;
            }
            else
            {
                break;
            }
        }
        float4 _150;
        if (_96)
        {
            _150 = UniformBlock.palette_offset + (UniformBlock.palette_amplitude * cos(((UniformBlock.palette_frequency * (((float(_90) - log2(log2(dot(_87, _87)))) + 4.0) / float(_95))) + UniformBlock.palette_phase) * 6.28318023681640625));
        }
        else
        {
            _150 = UniformBlock.interior_color;
        }
        output_image.write(float4(_150.xyz, 1.0), uint2(gl_GlobalInvocationID.xy));
        break;
    } while(false);
}

