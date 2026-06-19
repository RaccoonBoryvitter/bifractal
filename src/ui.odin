#+feature dynamic-literals
package main

import intr "base:intrinsics"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

import "core:fmt"

import mu "vendor:microui"
import sdl "vendor:sdl3"

// Types

@(private = "file")
RGBA8 :: distinct [4]u8

UIVertex :: struct {
    position : [2]f32,
    uv :       [2]f32,
    color :    [4]f32,
}

UIGlobals :: struct {
    screen_size : [2]f32,
}

// Functions

create_font_texture :: proc(device : ^sdl.GPUDevice) -> ^sdl.GPUTexture {
    atlas_size := len(mu.default_atlas_alpha)
    atlas_byte_size := atlas_size * size_of(RGBA8)

    raw_atlas := make([]RGBA8, atlas_size)
    defer delete(raw_atlas)

    for alpha, index in mu.default_atlas_alpha {
        raw_atlas[index] = {255, 255, 255, alpha}
    }

    texture := sdl.CreateGPUTexture(
        device,
        sdl.GPUTextureCreateInfo {
            type = .D2,
            format = .R8G8B8A8_UNORM,
            width = mu.DEFAULT_ATLAS_WIDTH,
            height = mu.DEFAULT_ATLAS_HEIGHT,
            layer_count_or_depth = 1,
            num_levels = 1,
            usage = {.SAMPLER},
        },
    )

    transfer_buffer := sdl.CreateGPUTransferBuffer(
        device,
        sdl.GPUTransferBufferCreateInfo {
            size = u32(atlas_byte_size),
            usage = .UPLOAD,
        },
    )
    defer sdl.ReleaseGPUTransferBuffer(device, transfer_buffer)

    raw_transfer_buffer := sdl.MapGPUTransferBuffer(
        device,
        transfer_buffer,
        false,
    )
    intr.mem_copy_non_overlapping(
        raw_transfer_buffer,
        raw_data(raw_atlas),
        atlas_byte_size,
    )
    sdl.UnmapGPUTransferBuffer(device, transfer_buffer)

    command_buffer := sdl.AcquireGPUCommandBuffer(device)
    copy_pass := sdl.BeginGPUCopyPass(command_buffer)
    sdl.UploadToGPUTexture(
        copy_pass,
        sdl.GPUTextureTransferInfo {
            transfer_buffer = transfer_buffer,
            offset = 0,
        },
        sdl.GPUTextureRegion {
            texture = texture,
            w = mu.DEFAULT_ATLAS_WIDTH,
            h = mu.DEFAULT_ATLAS_HEIGHT,
            d = 1,
        },
        false,
    )
    sdl.EndGPUCopyPass(copy_pass)
    ok := sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {
        // TODO: replace it with logger from AppState later
        fmt.panicf("unable to submit GPU command buffer: %s", sdl.GetError())
    }

    return texture
}

push_rect :: proc(
    vertices : ^[]UIVertex,
    count : ^int,
    rect, uv : mu.Rect,
    color : mu.Color,
) {
    c := [4]f32 {
        f32(color.r) / 255,
        f32(color.g) / 255,
        f32(color.b) / 255,
        f32(color.a) / 255,
    }
    x0, y0 := f32(rect.x), f32(rect.y)
    x1, y1 := f32(rect.x + rect.w), f32(rect.y + rect.h)

    white := mu.default_atlas[mu.DEFAULT_ATLAS_WHITE]
    u0 := (f32(white.x) + 0.5) / f32(mu.DEFAULT_ATLAS_WIDTH)
    v0 := (f32(white.y) + 0.5) / f32(mu.DEFAULT_ATLAS_HEIGHT)

    vertices^[count^ + 0] = {{x0, y0}, {u0, v0}, c}
    vertices^[count^ + 1] = {{x1, y0}, {u0, v0}, c}
    vertices^[count^ + 2] = {{x1, y1}, {u0, v0}, c}
    vertices^[count^ + 3] = {{x0, y0}, {u0, v0}, c}
    vertices^[count^ + 4] = {{x1, y1}, {u0, v0}, c}
    vertices^[count^ + 5] = {{x0, y1}, {u0, v0}, c}
    count^ += 6
}

push_rect_uv :: proc(
    vertices : ^[]UIVertex,
    count : ^int,
    rect, src : mu.Rect,
    color : mu.Color,
) {
    c := [4]f32 {
        f32(color.r) / 255,
        f32(color.g) / 255,
        f32(color.b) / 255,
        f32(color.a) / 255,
    }
    x0, y0 := f32(rect.x), f32(rect.y)
    x1, y1 := f32(rect.x + rect.w), f32(rect.y + rect.h)

    u0 := f32(src.x) / mu.DEFAULT_ATLAS_WIDTH
    v0 := f32(src.y) / mu.DEFAULT_ATLAS_HEIGHT
    u1 := f32(src.x + src.w) / mu.DEFAULT_ATLAS_WIDTH
    v1 := f32(src.y + src.h) / mu.DEFAULT_ATLAS_HEIGHT

    vertices^[count^ + 0] = {{x0, y0}, {u0, v0}, c}
    vertices^[count^ + 1] = {{x1, y0}, {u1, v0}, c}
    vertices^[count^ + 2] = {{x1, y1}, {u1, v1}, c}
    vertices^[count^ + 3] = {{x0, y0}, {u0, v0}, c}
    vertices^[count^ + 4] = {{x1, y1}, {u1, v1}, c}
    vertices^[count^ + 5] = {{x0, y1}, {u0, v1}, c}
    count^ += 6
}

palette_row :: proc(ui : ^mu.Context, label : string, color : ^[3]f32) {
    mu.layout_row(ui, {-1}, 0)
    mu.label(ui, label)

    container := mu.get_current_container(ui)
    padding := ui.style.padding
    spacing := ui.style.spacing
    available := container.body.w - padding * 2 - spacing * 2
    col_w := available / 3

    mu.layout_row(ui, {col_w, col_w, col_w}, 0)
    mu.slider(ui, &color.r, 0, 1.0)
    mu.slider(ui, &color.g, 0, 1.0)
    mu.slider(ui, &color.b, 0, 1.0)
}

// State/pipeline management

init_ui_pipeline :: proc(state : ^AppState) -> bool {
    ui_vertex_shader := create_gpu_shader(
        state.gpu.device,
        UI_VERTEX_SHADER_PATH,
        .VERTEX,
        num_uniform_buffers = 1,
    )
    if ui_vertex_shader == nil {
        return false
    }

    ui_fragment_shader := create_gpu_shader(
        state.gpu.device,
        UI_FRAGMENT_SHADER_PATH,
        .FRAGMENT,
        num_samplers = 1,
    )
    if ui_fragment_shader == nil {
        return false
    }

    ui_vertex_buffer_descs := [1]sdl.GPUVertexBufferDescription {
        {slot = 0, pitch = size_of(UIVertex), input_rate = .VERTEX},
    }

    ui_vertex_attrs := [3]sdl.GPUVertexAttribute {
        {location = 0, buffer_slot = 0, format = .FLOAT2, offset = 0},
        {
            location = 1,
            buffer_slot = 0,
            format = .FLOAT2,
            offset = size_of(f32) * 2,
        },
        {
            location = 2,
            buffer_slot = 0,
            format = .FLOAT4,
            offset = size_of(f32) * 4,
        },
    }

    color_targets := [1]sdl.GPUColorTargetDescription {
        {
            format = sdl.GetGPUSwapchainTextureFormat(
                state.gpu.device,
                state.window,
            ),
            blend_state = {
                enable_blend = true,
                color_blend_op = .ADD,
                alpha_blend_op = .ADD,
                src_color_blendfactor = .SRC_ALPHA,
                dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
                src_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
                dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
            },
        },
    }

    ui_pipeline := sdl.CreateGPUGraphicsPipeline(
        state.gpu.device,
        sdl.GPUGraphicsPipelineCreateInfo {
            vertex_shader = ui_vertex_shader,
            fragment_shader = ui_fragment_shader,
            primitive_type = .TRIANGLELIST,
            vertex_input_state = {
                num_vertex_buffers = 1,
                vertex_buffer_descriptions = raw_data(
                    ui_vertex_buffer_descs[:],
                ),
                num_vertex_attributes = 3,
                vertex_attributes = raw_data(ui_vertex_attrs[:]),
            },
            target_info = {
                num_color_targets = 1,
                color_target_descriptions = raw_data(color_targets[:]),
            },
        },
    )
    sdl.ReleaseGPUShader(state.gpu.device, ui_vertex_shader)
    sdl.ReleaseGPUShader(state.gpu.device, ui_fragment_shader)
    state.gpu.ui_pipeline = ui_pipeline

    return true
}

init_ui_resources :: proc(state : ^AppState) {
    state.gpu.ui_vertex_buffer = sdl.CreateGPUBuffer(
        state.gpu.device,
        sdl.GPUBufferCreateInfo {
            size = size_of(UIVertex) * MAX_UI_VERTICES,
            usage = {.VERTEX},
        },
    )
    state.gpu.ui_transfer_buffer = sdl.CreateGPUTransferBuffer(
        state.gpu.device,
        sdl.GPUTransferBufferCreateInfo {
            size = size_of(UIVertex) * MAX_UI_VERTICES,
            usage = .UPLOAD,
        },
    )

    state.gpu.ui_font_texture = create_font_texture(state.gpu.device)
    state.gpu.ui_font_sampler = sdl.CreateGPUSampler(
        state.gpu.device,
        sdl.GPUSamplerCreateInfo{min_filter = .NEAREST, mag_filter = .NEAREST},
    )

    mu.init(&state.ui_context)
    state.ui_context.text_width = mu.default_atlas_text_width
    state.ui_context.text_height = mu.default_atlas_text_height
}

// Input management

handle_ui_events :: proc(event : ^sdl.Event, state : ^AppState) {
    #partial switch event.type {
        case .MOUSE_MOTION:
            mu.input_mouse_move(
                    &state.ui_context,
                    i32(event.motion.x),
                    i32(event.motion.y),
                )
        case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
            btn : mu.Mouse
            switch event.button.button {
                case sdl.BUTTON_LEFT: btn = .LEFT
                case sdl.BUTTON_MIDDLE: btn = .MIDDLE
                case sdl.BUTTON_RIGHT: btn = .RIGHT
            }
            if event.type == .MOUSE_BUTTON_DOWN {
                mu.input_mouse_down(
                    &state.ui_context,
                    i32(event.button.x),
                    i32(event.button.y),
                    btn,
                )
            }
             else {
                mu.input_mouse_up(
                    &state.ui_context,
                    i32(event.button.x),
                    i32(event.button.y),
                    btn,
                )
            }
        case .MOUSE_WHEEL: if state.ui_context.hover_root != nil {
                    mu.input_scroll(
                        &state.ui_context,
                        0,
                        i32(event.wheel.y * -30),
                    )
                }
        case .TEXT_INPUT: on_microui_text_input(event, state)
        case .KEY_DOWN, .KEY_UP:
            k, ok := KEY_MAP[event.key.key]
            if !ok {
                break
            }
            if event.type == .KEY_DOWN {
                mu.input_key_down(&state.ui_context, k)
            }
             else {
                mu.input_key_up(&state.ui_context, k)
            }

            if .CTRL in state.ui_context.key_down_bits {
                break
            }
    }
}

@(private = "file")
on_microui_text_input :: proc(event : ^sdl.Event, state : ^AppState) {
    c_text := event.text.text
    if c_text == nil {
        return
    }

    text, err := strings.clone_from_cstring(c_text, context.temp_allocator)
    if err != .None {
        return
    }
    defer delete(text, context.temp_allocator)

    ch, size := utf8.decode_rune(text)
    if len(text) == size && unicode.is_print(ch) {
        mu.input_text(&state.ui_context, text)
    }
}
