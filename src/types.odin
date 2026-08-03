package main

import "core:log"
import "core:mem"

import "events"
import "fractal"
import "geom"
import "palette"
import "platform"
import "ui"

import sdl "vendor:sdl3"

Vec2 :: geom.Vec2
Extent_2D :: geom.Extent_2D

Channel :: ui.Channel
Ui_State :: ui.Ui_State
Ui_View :: ui.Ui_View
create_imgui_ui :: ui.create_imgui_ui

Window :: platform.Window
Gpu_Context :: platform.Gpu_Context
init_window :: platform.init_window
init_gpu :: platform.init_gpu
create_compute_pipeline :: platform.create_compute_pipeline
resize_gpu_output :: platform.resize_gpu_output
sdl_log_callback :: platform.sdl_log_callback
WINDOW_TITLE :: platform.WINDOW_TITLE
WINDOW_RESOLUTION :: platform.WINDOW_RESOLUTION
SHADER_FORMAT :: platform.SHADER_FORMAT

Palette :: palette.Palette
Palette_Preset :: palette.Palette_Preset
Palette_State :: palette.Palette_State
Palette_Color_Kind :: palette.Palette_Color_Kind
apply_palette_preset :: palette.apply_palette_preset
mirror_palette :: palette.mirror_palette
rotate_palette :: palette.rotate_palette
randomize_palette :: palette.randomize_palette
cosine_palette_cpu :: palette.cosine_palette_cpu
palette_create_samples :: palette.palette_create_samples
PALETTE_SWATCH_STEPS :: palette.PALETTE_SWATCH_STEPS
PALETTE_PRESET_SWATCH_STEPS :: palette.PALETTE_PRESET_SWATCH_STEPS
PALETTE_PRESETS :: palette.PALETTE_PRESETS

Fractal_Kind :: fractal.Fractal_Kind
Fractal_View :: fractal.Fractal_View
Fractal_Camera :: fractal.Fractal_Camera
Fractal_Command :: fractal.Fractal_Command
Fractal_Input :: fractal.Fractal_Input
Fractal_Base :: fractal.Fractal_Base
Fractal_Data :: fractal.Fractal_Data
Mandelbrot_Data :: fractal.Mandelbrot_Data
Fractal :: fractal.Fractal
Fractal_Params :: fractal.Mandelbrot_Params
Fractal_Uniform :: fractal.Mandelbrot_Uniform
MANDELBROT_SHADER :: fractal.MANDELBROT_SHADER
SHADER_ENTRY :: fractal.MANDELBROT_SHADER_ENTRY
view_screen_to_complex :: fractal.view_screen_to_complex
get_window_pixel_scale :: fractal.get_window_pixel_scale
reset_fractal_view :: fractal.reset_fractal_view
fractal_process_input :: fractal.fractal_process_input
fractal_apply_command :: fractal.fractal_apply_command
init_fractal_state :: fractal.init_fractal_state
fractal_uniform_size :: fractal.fractal_uniform_size
fractal_make_uniform :: fractal.fractal_make_uniform
FRACTAL_PAN_FACTOR :: fractal.FRACTAL_PAN_FACTOR
FRACTAL_ZOOM_SCROLL_FACTOR :: fractal.FRACTAL_ZOOM_SCROLL_FACTOR
FRACTAL_MOUSE_DRAG_SCALE :: fractal.FRACTAL_MOUSE_DRAG_SCALE
FRACTAL_MIN_ZOOM :: fractal.FRACTAL_MIN_ZOOM
FRACTAL_MIN_ZOOM_LOG :: fractal.FRACTAL_MIN_ZOOM_LOG
FRACTAL_MIN_ITERATIONS :: fractal.FRACTAL_MIN_ITERATIONS
FRACTAL_MAX_ITERATIONS :: fractal.FRACTAL_MAX_ITERATIONS
FRACTAL_ITERATION_STEP :: fractal.FRACTAL_ITERATION_STEP
FRACTAL_ITERATION_DECREASE_STEP :: fractal.FRACTAL_ITERATION_DECREASE_STEP

View_Reset :: events.View_Reset
Max_Iter_Changed :: events.Max_Iter_Changed
Window_Resized :: events.Window_Resized
Palette_Banded_Changed :: events.Palette_Banded_Changed
Palette_Mirrored :: events.Palette_Mirrored
Palette_Rotated :: events.Palette_Rotated
Palette_Randomized :: events.Palette_Randomized
Palette_Preset_Applied :: events.Palette_Preset_Applied
Palette_Color_Changed :: events.Palette_Color_Changed
Mandelbrot_Power_Changed :: events.Mandelbrot_Power_Changed
Interior_Color_Changed :: events.Interior_Color_Changed
App_Event :: events.App_Event
App_Events :: events.App_Events

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
