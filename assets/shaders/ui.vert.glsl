#version 460

layout(location = 0) in vec2 a_position;
layout(location = 1) in vec2 a_uv;
layout(location = 2) in vec4 a_color;

layout(location = 0) out vec2 v_uv;
layout(location = 1) out vec4 v_color;

layout(set = 1, binding = 0) uniform Globals {
    vec2 screen_size;
};

void main() {
    v_uv    = a_uv;
    v_color = a_color;
    gl_Position = vec4(
        (a_position.x / screen_size.x) * 2.0 - 1.0,
        -((a_position.y / screen_size.y) * 2.0 - 1.0),
        0.0, 1.0
    );
}