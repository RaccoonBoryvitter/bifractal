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
        float2 _83;
        int _86;
        _83 = float2(0.0);
        _86 = 0;
        float2 _84;
        int _87;
        int _91;
        bool _92;
        for (;;)
        {
            _91 = UniformBlock.max_iter;
            _92 = _86 < _91;
            bool _97;
            if (_92)
            {
                _97 = dot(_83, _83) < 4.0;
            }
            else
            {
                _97 = false;
            }
            if (_97)
            {
                float2 _117;
                do
                {
                    float _103 = dot(_83, _83);
                    if (_103 < 1.0000000195414813782625560981111e-24)
                    {
                        _117 = float2(0.0);
                        break;
                    }
                    float _112 = UniformBlock.power * precise::atan2(_83.y, _83.x);
                    _117 = float2(cos(_112), sin(_112)) * powr(_103, UniformBlock.power * 0.5);
                    break;
                } while(false);
                _84 = abs(_117) + _81;
                _87 = _86 + 1;
                _83 = _84;
                _86 = _87;
                continue;
            }
            else
            {
                break;
            }
        }
        float4 _145;
        if (_92)
        {
            _145 = UniformBlock.palette_offset + (UniformBlock.palette_amplitude * cos(((UniformBlock.palette_frequency * (((float(_86) - log2(log2(dot(_83, _83)))) + 4.0) / float(_91))) + UniformBlock.palette_phase) * 6.28318023681640625));
        }
        else
        {
            _145 = UniformBlock.interior_color;
        }
        output_image.write(float4(_145.xyz, 1.0), uint2(gl_GlobalInvocationID.xy));
        break;
    } while(false);
}

