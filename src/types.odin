package main

import "base:runtime"

import mu "vendor:microui"
import sdl "vendor:sdl3"

Gpu_Resources :: struct {
    device :             ^sdl.GPUDevice,
    compute_pipeline :   ^sdl.GPUComputePipeline,
    texture :            ^sdl.GPUTexture,
    ui_pipeline :        ^sdl.GPUGraphicsPipeline,
    ui_vertex_buffer :   ^sdl.GPUBuffer,
    ui_transfer_buffer : ^sdl.GPUTransferBuffer,
    ui_font_texture :    ^sdl.GPUTexture,
    ui_font_sampler :    ^sdl.GPUSampler,
}

Fractal_Uniform :: struct {
    center :     [2]f32,
    zoom :       f32,
    max_iter :   i32,
    palette_a :  [4]f32,
    palette_b :  [4]f32,
    palette_c :  [4]f32,
    palette_d :  [4]f32,
    resolution : [2]f32,
}

Fractal_State :: struct {
    uniform :        Fractal_Uniform,
    zoom_level :     f32,
    is_dragging :    bool,
    default_cursor : ^sdl.Cursor,
    move_cursor :    ^sdl.Cursor,
}

Palette_Preset :: struct {
    name : string,
    a :    [4]f32,
    b :    [4]f32,
    c :    [4]f32,
    d :    [4]f32,
}

Ui_Vertex :: struct {
    position : [2]f32,
    uv :       [2]f32,
    color :    [4]f32,
}

Ui_Globals :: struct {
    screen_size : [2]f32,
}

Resolution :: struct {
    w, h : u32,
}

App_State :: struct {
    ctx :               runtime.Context,
    window :            ^sdl.Window,
    window_resolution : Resolution,
    gpu :               Gpu_Resources,
    fractal :           Fractal_State,
    ui_context :        mu.Context,
    fps_frame_count :   u32,
    fps_last_ticks :    u64,
    fps_current :       f32,
}
