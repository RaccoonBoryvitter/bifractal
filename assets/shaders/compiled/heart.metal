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
    float power;
};

kernel void main0(constant type_UniformBlock& UniformBlock [[buffer(0)]], texture2d<float, access::write> output_image [[texture(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    do
    {
        int2 _51 = int2(gl_GlobalInvocationID.xy);
        bool _65;
        if (_51.x < int(UniformBlock.resolution.x))
        {
            _65 = _51.y >= int(UniformBlock.resolution.y);
        }
        else
        {
            _65 = true;
        }
        if (_65)
        {
            break;
        }
        float2 _81 = ((float2(_51) - (UniformBlock.resolution * 0.5)) / float2(UniformBlock.resolution.y * UniformBlock.zoom)) + UniformBlock.center;
        _81.x = abs(_81.x);
        float2 _86;
        int _89;
        _86 = float2(0.0);
        _89 = 0;
        float2 _87;
        int _90;
        int _94;
        bool _95;
        for (;;)
        {
            _94 = UniformBlock.max_iter;
            _95 = _89 < _94;
            bool _100;
            if (_95)
            {
                _100 = dot(_86, _86) < 4.0;
            }
            else
            {
                _100 = false;
            }
            if (_100)
            {
                float2 _120;
                do
                {
                    float _106 = dot(_86, _86);
                    if (_106 < 1.0000000195414813782625560981111e-24)
                    {
                        _120 = float2(0.0);
                        break;
                    }
                    float _115 = UniformBlock.power * precise::atan2(_86.y, _86.x);
                    _120 = float2(cos(_115), sin(_115)) * powr(_106, UniformBlock.power * 0.5);
                    break;
                } while(false);
                _87 = _120 + _81;
                _90 = _89 + 1;
                _86 = _87;
                _89 = _90;
                continue;
            }
            else
            {
                break;
            }
        }
        float4 _147;
        if (_95)
        {
            _147 = UniformBlock.palette_offset + (UniformBlock.palette_amplitude * cos(((UniformBlock.palette_frequency * (((float(_89) - log2(log2(dot(_86, _86)))) + 4.0) / float(_94))) + UniformBlock.palette_phase) * 6.28318023681640625));
        }
        else
        {
            _147 = UniformBlock.interior_color;
        }
        output_image.write(float4(_147.xyz, 1.0), uint2(gl_GlobalInvocationID.xy));
        break;
    } while(false);
}

