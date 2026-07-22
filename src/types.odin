package main

import "core:log"
import "core:math/rand"
import "core:mem"

import im "deps:imgui"
import sdl "vendor:sdl3"

Vec2 :: distinct [2]f32

Channel :: enum {
    Red,
    Green,
    Blue,
}

Extent_2D :: struct {
    w, h: u32,
}

Window :: struct {
    handle: ^sdl.Window,
    size:   Extent_2D,
}

Gpu_Context :: struct {
    device:      ^sdl.GPUDevice,
    pipeline:    ^sdl.GPUComputePipeline,
    output:      ^sdl.GPUTexture,
    output_size: Extent_2D,
    name:        string,
    driver:      string,
    valid:       bool,
}

Palette :: struct {
    offset, amplitude, frequency, phase: [4]f32,
}

Fractal_View :: struct {
    center: [2]f32,
    zoom:   f32,
}

Fractal_Camera :: struct {
    view:        Fractal_View,
    is_dragging: bool,
    drag_start:  Vec2,
}

Fractal_Command :: enum {
    None,
    Pan,
    Zoom,
    Reset_View,
    Increase_Iter,
    Decrease_Iter,
    Drag_Start,
    Drag_End,
}

Fractal_Input :: struct {
    cmd:   Fractal_Command,
    pos:   Vec2,
    delta: Vec2,
}

Fractal_Params :: struct {
    max_iter:      i32,
    using palette: Palette,
    resolution:    [2]f32,
}

Fractal_Uniform :: struct {
    center:       [2]f32,
    zoom:         f32,
    using params: Fractal_Params,
}

Fractal :: struct {
    camera:         Fractal_Camera,
    params:         Fractal_Params,
    zoom_level:     f32,
    default_cursor: ^sdl.Cursor,
    move_cursor:    ^sdl.Cursor,
}

Palette_Preset :: struct {
    name:          string,
    using palette: Palette,
}

Palette_State :: struct {
    banded:     bool,
    snapshot:   Maybe(Palette_Preset),
    rand_state: rand.Default_Random_State,
}

Palette_Color_Kind :: enum {
    Offset,
    Amplitude,
    Frequency,
    Phase,
}

View_Reset :: struct {}
Max_Iter_Changed :: struct {
    value: i32,
}
Window_Resized :: struct {
    size: Extent_2D,
}
Palette_Banded_Changed :: struct {
    banded: bool,
}
Palette_Mirrored :: struct {}
Palette_Rotated :: struct {
    delta: f32,
}
Palette_Randomized :: struct {}
Palette_Preset_Applied :: struct {
    preset: Palette_Preset,
}
Palette_Color_Changed :: struct {
    kind:  Palette_Color_Kind,
    value: [4]f32,
}

App_Event :: union {
    View_Reset,
    Max_Iter_Changed,
    Window_Resized,
    Palette_Banded_Changed,
    Palette_Mirrored,
    Palette_Rotated,
    Palette_Randomized,
    Palette_Preset_Applied,
    Palette_Color_Changed,
}

App_Events :: struct {
    queue: [dynamic]App_Event,
}

Frame_Pass :: enum {
    None,
    Compute,
    Blit,
    Ui,
}

Render_Context :: struct {
    cmd:     ^sdl.GPUCommandBuffer,
    scratch: mem.Arena,
    pass:    Frame_Pass,
}

Ui_State :: struct {
    ctx:              ^im.Context,
    mouse_complex:    complex64,
    selected_channel: Channel,
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
    events:  App_Events,
}
