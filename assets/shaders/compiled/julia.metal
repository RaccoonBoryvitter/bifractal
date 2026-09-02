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
    float2 constant0;
};

kernel void main0(constant type_UniformBlock& UniformBlock [[buffer(0)]], texture2d<float, access::write> output_image [[texture(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    do
    {
        int2 _53 = int2(gl_GlobalInvocationID.xy);
        bool _67;
        if (_53.x < int(UniformBlock.resolution.x))
        {
            _67 = _53.y >= int(UniformBlock.resolution.y);
        }
        else
        {
            _67 = true;
        }
        if (_67)
        {
            break;
        }
        float2 _88;
        int _91;
        _88 = ((float2(_53) - (UniformBlock.resolution * 0.5)) / float2(UniformBlock.resolution.y * UniformBlock.zoom)) + (UniformBlock.center_hi + UniformBlock.center_lo);
        _91 = 0;
        float2 _89;
        int _92;
        int _96;
        bool _97;
        for (;;)
        {
            _96 = UniformBlock.max_iter;
            _97 = _91 < _96;
            bool _102;
            if (_97)
            {
                _102 = dot(_88, _88) < 4.0;
            }
            else
            {
                _102 = false;
            }
            if (_102)
            {
                float2 _119;
                do
                {
                    float _106 = dot(_88, _88);
                    if (_106 < 1.0000000195414813782625560981111e-24)
                    {
                        _119 = float2(0.0);
                        break;
                    }
                    float _114 = 2.0 * precise::atan2(_88.y, _88.x);
                    _119 = float2(cos(_114), sin(_114)) * powr(_106, 1.0);
                    break;
                } while(false);
                _89 = _119 + UniformBlock.constant0;
                _92 = _91 + 1;
                _88 = _89;
                _91 = _92;
                continue;
            }
            else
            {
                break;
            }
        }
        float4 _148;
        if (_97)
        {
            _148 = UniformBlock.palette_offset + (UniformBlock.palette_amplitude * cos(((UniformBlock.palette_frequency * (((float(_91) - log2(log2(dot(_88, _88)))) + 4.0) / float(_96))) + UniformBlock.palette_phase) * 6.28318023681640625));
        }
        else
        {
            _148 = UniformBlock.interior_color;
        }
        output_image.write(float4(_148.xyz, 1.0), uint2(gl_GlobalInvocationID.xy));
        break;
    } while(false);
}

