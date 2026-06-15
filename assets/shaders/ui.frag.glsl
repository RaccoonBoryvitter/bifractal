#version 460

layout(location = 0) in vec2 v_uv;
layout(location = 1) in vec4 v_color;
layout(location = 0) out vec4 out_color;

layout(set = 2, binding = 0) uniform sampler2D u_texture;

void main() {
    out_color = v_color * texture(u_texture, v_uv);
}
