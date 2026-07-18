package main

import "base:runtime"

import "core:log"
import "core:math/rand"

import im "deps:imgui"
import sdl "vendor:sdl3"

Extent_2D :: struct {
    w, h: u32,
}

Window :: struct {
    handle: ^sdl.Window,
    size:   Extent_2D,
}

Gpu_Context :: struct {
    device:           ^sdl.GPUDevice,
    compute_pipeline: ^sdl.GPUComputePipeline,
    texture:          ^sdl.GPUTexture,
    name:             string,
    driver:           string,
}

Fractal :: struct {
    params:         Fractal_Params,
    zoom_level:     f32,
    is_dragging:    bool,
    default_cursor: ^sdl.Cursor,
    move_cursor:    ^sdl.Cursor,
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

Palette_Preset :: struct {
    name: string,
    a:    [4]f32,
    b:    [4]f32,
    c:    [4]f32,
    d:    [4]f32,
}

Palette_State :: struct {
    banded:     bool,
    snapshot:   Maybe(Palette_Preset),
    rand_state: rand.Default_Random_State,
}

Ui_State :: struct {
    ctx:           ^im.Context,
    mouse_complex: complex64,
}

Time :: struct {
    frame_count: u32,
    last_ticks:  u64,
    current:     f32,
}

App_Context :: struct {
    window:  Window,
    logger:  log.Logger,
    gpu:     Gpu_Context,
    fractal: Fractal,
    palette: Palette_State,
    ui:      Ui_State,
    time:    Time,
}
