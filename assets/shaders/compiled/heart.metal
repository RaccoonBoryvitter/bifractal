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
        _85.x = abs(_85.x);
        float2 _90;
        int _93;
        _90 = float2(0.0);
        _93 = 0;
        float2 _91;
        int _94;
        int _98;
        bool _99;
        for (;;)
        {
            _98 = UniformBlock.max_iter;
            _99 = _93 < _98;
            bool _104;
            if (_99)
            {
                _104 = dot(_90, _90) < 4.0;
            }
            else
            {
                _104 = false;
            }
            if (_104)
            {
                float2 _124;
                do
                {
                    float _110 = dot(_90, _90);
                    if (_110 < 1.0000000195414813782625560981111e-24)
                    {
                        _124 = float2(0.0);
                        break;
                    }
                    float _119 = UniformBlock.power * precise::atan2(_90.y, _90.x);
                    _124 = float2(cos(_119), sin(_119)) * powr(_110, UniformBlock.power * 0.5);
                    break;
                } while(false);
                _91 = _124 + _85;
                _94 = _93 + 1;
                _90 = _91;
                _93 = _94;
                continue;
            }
            else
            {
                break;
            }
        }
        float4 _151;
        if (_99)
        {
            _151 = UniformBlock.palette_offset + (UniformBlock.palette_amplitude * cos(((UniformBlock.palette_frequency * (((float(_93) - log2(log2(dot(_90, _90)))) + 4.0) / float(_98))) + UniformBlock.palette_phase) * 6.28318023681640625));
        }
        else
        {
            _151 = UniformBlock.interior_color;
        }
        output_image.write(float4(_151.xyz, 1.0), uint2(gl_GlobalInvocationID.xy));
        break;
    } while(false);
}

