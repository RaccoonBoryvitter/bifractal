package main

import "base:runtime"

import "core:log"
import "core:math/rand"

import im "deps:imgui"
import sdl "vendor:sdl3"

Gpu_Resources :: struct {
    device:           ^sdl.GPUDevice,
    compute_pipeline: ^sdl.GPUComputePipeline,
    texture:          ^sdl.GPUTexture,
}

Fractal_Params :: struct {
    center:     [2]f32,
    zoom:       f32,
    max_iter:   i32,
    palette_a:  [4]f32,
    palette_b:  [4]f32,
    palette_c:  [4]f32,
    palette_d:  [4]f32,
    resolution: [2]f32,
}

Fractal_State :: struct {
    params:         Fractal_Params,
    zoom_level:     f32,
    is_dragging:    bool,
    default_cursor: ^sdl.Cursor,
    move_cursor:    ^sdl.Cursor,
}

Palette_Preset :: struct {
    name: string,
    a:    [4]f32,
    b:    [4]f32,
    c:    [4]f32,
    d:    [4]f32,
}

Resolution :: struct {
    w, h: u32,
}

ImGui_Resources :: struct {
    ctx: ^im.Context,
}

App_State :: struct {
    window:               ^sdl.Window,
    window_resolution:    Resolution,
    logger:               log.Logger,
    gpu:                  Gpu_Resources,
    gpu_name:             string,
    gpu_driver:           string,
    mouse_complex:        complex64,
    fractal:              Fractal_State,
    palette_banded:       bool,
    palette_snapshot:     Palette_Preset,
    palette_has_snapshot: bool,
    rand_state:           rand.Default_Random_State,
    fps_frame_count:      u32,
    fps_last_ticks:       u64,
    fps_current:          f32,
    im_context:           ^im.Context,
}
