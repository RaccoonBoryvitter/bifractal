#+feature dynamic-literals
package main

import intr "base:intrinsics"
import "core:math"
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

UiLayout :: struct {
    navigation : mu.Rect,
    palette :    mu.Rect,
    stats :      mu.Rect,
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

available_width :: proc(ctx : ^mu.Context) -> i32 {
    container := mu.get_current_container(ctx)
    return container.body.w - ctx.style.padding * 2
}

create_sidebar_layout :: proc(width, height : u32) -> mu.Rect {
    margin : i32 = 10
    panel_w := clamp(i32(f32(width) * 0.22), 280, 420)
    panel_h := i32(height) - margin * 2

    return mu.Rect{i32(width) - panel_w - margin, margin, panel_w, panel_h}
}

create_ui :: proc(state : ^AppState) {
    context = state.ctx
    defer free_all(context.temp_allocator)

    ui_ctx := &state.ui_context
    mu.begin(ui_ctx)
    defer mu.end(ui_ctx)

    layout := create_sidebar_layout(state.window_width, state.window_height)

    root_window := mu.begin_window(
        ui_ctx,
        "Sidebar",
        layout,
        {.EXPANDED})
    defer mu.end_window(ui_ctx)
    if !root_window {
        return
    }

    navigation_section := mu.header(ui_ctx, "Navigation")
    if .ACTIVE in navigation_section {
        mu.layout_row(ui_ctx, {-1}, 0)

        mu.label(ui_ctx, "Zoom:")
        zoom_format :=
            state.fractal.uniform.zoom > 1_000_000 || state.fractal.uniform.zoom < 0.000_001 ? "%e" : "%.4f"
        mu.label(ui_ctx, fmt.tprintf(zoom_format, state.fractal.uniform.zoom))

        mu.label(ui_ctx, "Center:")
        mu.label(
            ui_ctx,
            fmt.tprintf(
                "{:+.6f} {:+.6f}i",
                state.fractal.uniform.center.x,
                state.fractal.uniform.center.y,
            ),
        )

        if ui_ctx.hover_root != nil {
            mu.label(ui_ctx, "Mouse:")
            mu.label(ui_ctx, "--")
        }
         else {
            mouse_x, mouse_y : f32
            _ = sdl.GetMouseState(&mouse_x, &mouse_y)

            complex_coords := screen_to_complex(
                mouse_x,
                mouse_y,
                state.window_width,
                state.window_height,
                state.fractal.uniform.center,
                state.fractal.uniform.zoom,
            )

            mu.label(ui_ctx, "Mouse:")
            mu.label(
                ui_ctx,
                fmt.tprintf(
                    "{:+.6f} {:+.6f}i",
                    real(complex_coords),
                    imag(complex_coords),
                ),
            )
        }

        mu.label(ui_ctx, "Iterations:")
        max_iter_float := f32(state.fractal.uniform.max_iter)
        mu.slider(ui_ctx, &max_iter_float, 8, 1024, 1)
        state.fractal.uniform.max_iter = i32(max_iter_float)

        reset_button := mu.button(ui_ctx, "Reset View")
        if .SUBMIT in reset_button {
            reset_fractal_view(
                &state.fractal.uniform,
                &state.fractal.zoom_level,
            )
        }
    }

    palette_section := mu.header(ui_ctx, "Palette")
    if .ACTIVE in palette_section {
        spacing := ui_ctx.style.spacing
        available := available_width(ui_ctx)

        mu.layout_row(ui_ctx, {-1}, 0)
        mu.label(ui_ctx, "Gradient Preview")

        mu.layout_row(ui_ctx, {-1}, 40)
        swatch_rect := mu.layout_next(ui_ctx)
        step_w := f32(swatch_rect.w) / f32(PALETTE_SWATCH_STEPS)

        for i in 0 ..< PALETTE_SWATCH_STEPS {
            t := f32(i) / f32(PALETTE_SWATCH_STEPS - 1)
            color := cosine_palette_cpu(
                t,
                state.fractal.uniform.palette_a,
                state.fractal.uniform.palette_b,
                state.fractal.uniform.palette_c,
                state.fractal.uniform.palette_d,
            )
            slice := mu.Rect {
                x = swatch_rect.x + i32(f32(i) * step_w),
                y = swatch_rect.y,
                w = i32(math.ceil(step_w)) + 1,
                h = swatch_rect.h,
            }
            mu.draw_rect(
                ui_ctx,
                slice,
                mu.Color {
                    r = u8(math.clamp(color.r, 0, 1) * 255),
                    g = u8(math.clamp(color.g, 0, 1) * 255),
                    b = u8(math.clamp(color.b, 0, 1) * 255),
                    a = 255,
                },
            )
        }

        palette_row(ui_ctx, "a:", &state.fractal.uniform.palette_a)
        palette_row(ui_ctx, "b:", &state.fractal.uniform.palette_b)
        palette_row(ui_ctx, "c:", &state.fractal.uniform.palette_c)
        palette_row(ui_ctx, "d:", &state.fractal.uniform.palette_d)

        presets_header := mu.header(ui_ctx, "Presets")
        if .ACTIVE in presets_header {
            button_w := available - PALETTE_SWATCH_WIDTH - spacing

            for preset in PALETTE_PRESETS {
                mu.layout_row(ui_ctx, {button_w, PALETTE_SWATCH_WIDTH}, 0)

                preset_button := mu.button(ui_ctx, preset.name)
                if .SUBMIT in preset_button {
                    apply_palette_preset(&state.fractal.uniform, preset)
                }

                swatch_container_rect := mu.layout_next(ui_ctx)
                step_w :=
                    f32(swatch_container_rect.w) / PALETTE_PRESET_SWATCH_STEPS
                for i in 0 ..< PALETTE_PRESET_SWATCH_STEPS {
                    t := f32(i) / f32(PALETTE_PRESET_SWATCH_STEPS - 1)
                    color := cosine_palette_cpu(
                        t,
                        preset.a,
                        preset.b,
                        preset.c,
                        preset.d,
                    )
                    slice_rect := mu.Rect {
                        x = swatch_container_rect.x + i32(f32(i) * step_w),
                        y = swatch_container_rect.y,
                        w = i32(math.ceil(step_w)) + 1,
                        h = swatch_container_rect.h,
                    }
                    mu.draw_rect(
                        ui_ctx,
                        slice_rect,
                        mu.Color {
                            r = u8(math.clamp(color.r, 0, 1) * 255),
                            g = u8(math.clamp(color.g, 0, 1) * 255),
                            b = u8(math.clamp(color.b, 0, 1) * 255),
                            a = 255,
                        },
                    )
                }
            }
        }
    }

    stats_section := mu.header(ui_ctx, "Stats")
    if .ACTIVE in stats_section {
        mu.layout_row(ui_ctx, {-1}, 0)

        mu.label(ui_ctx, "FPS:")
        mu.label(ui_ctx, "to be done")

        mu.label(ui_ctx, "GPU:")
        gpu_props := sdl.GetGPUDeviceProperties(state.gpu.device)
        gpu_name := sdl.GetStringProperty(
            gpu_props,
            sdl.PROP_GPU_DEVICE_NAME_STRING,
            "Unknown",
        )
        mu.label(ui_ctx, string(gpu_name))

        mu.label(ui_ctx, "Resolution:")
        mu.label(
            ui_ctx,
            fmt.tprintf("{:d}x{:d}", state.window_width, state.window_height),
        )
    }
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
