#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct type_UniformBlock
{
    float2 center;
    float zoom;
    int max_iter;
    float4 palette_offset;
    float4 palette_amplitude;
    float4 palette_frequency;
    float4 palette_phase;
    float4 interior_color;
    float2 resolution;
    float2 constant0;
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
        float2 _84;
        int _87;
        _84 = ((float2(_52) - (UniformBlock.resolution * 0.5)) / float2(UniformBlock.resolution.y * UniformBlock.zoom)) + UniformBlock.center;
        _87 = 0;
        float2 _85;
        int _88;
        int _92;
        bool _93;
        for (;;)
        {
            _92 = UniformBlock.max_iter;
            _93 = _87 < _92;
            bool _98;
            if (_93)
            {
                _98 = dot(_84, _84) < 4.0;
            }
            else
            {
                _98 = false;
            }
            if (_98)
            {
                float2 _115;
                do
                {
                    float _102 = dot(_84, _84);
                    if (_102 < 1.0000000195414813782625560981111e-24)
                    {
                        _115 = float2(0.0);
                        break;
                    }
                    float _110 = 2.0 * precise::atan2(_84.y, _84.x);
                    _115 = float2(cos(_110), sin(_110)) * powr(_102, 1.0);
                    break;
                } while(false);
                _85 = _115 + UniformBlock.constant0;
                _88 = _87 + 1;
                _84 = _85;
                _87 = _88;
                continue;
            }
            else
            {
                break;
            }
        }
        float4 _144;
        if (_93)
        {
            _144 = UniformBlock.palette_offset + (UniformBlock.palette_amplitude * cos(((UniformBlock.palette_frequency * (((float(_87) - log2(log2(dot(_84, _84)))) + 4.0) / float(_92))) + UniformBlock.palette_phase) * 6.28318023681640625));
        }
        else
        {
            _144 = UniformBlock.interior_color;
        }
        output_image.write(float4(_144.xyz, 1.0), uint2(gl_GlobalInvocationID.xy));
        break;
    } while(false);
}

