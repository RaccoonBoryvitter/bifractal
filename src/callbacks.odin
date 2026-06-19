package main

import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "base:runtime"

import sdl "vendor:sdl3"
import mu  "vendor:microui"

@(export)
SDL_AppInit :: proc "c" (
    appstate: ^rawptr,
    argc: c.int,
    argv: [^]cstring,
) -> sdl.AppResult {
    context = runtime.default_context()
    state := init_app(context)
    if state == nil {
        return .FAILURE
    }

    appstate^ = rawptr(state)
    return .CONTINUE
}

@(export)
SDL_AppEvent :: proc "c" (
    appstate: rawptr,
    event: ^sdl.Event,
) -> sdl.AppResult {
    state := (^AppState)(appstate)
    context = state.ctx

    // UI input handling
    #partial switch event.type {
    case .MOUSE_MOTION:
        mu.input_mouse_move(
            &state.ui_context,
            i32(event.motion.x),
            i32(event.motion.y)
        )
    case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
        btn : mu.Mouse
        switch event.button.button {
        case sdl.BUTTON_LEFT:   btn = .LEFT
        case sdl.BUTTON_MIDDLE: btn = .MIDDLE
        case sdl.BUTTON_RIGHT:  btn = .RIGHT
        }
        if event.type == .MOUSE_BUTTON_DOWN {
            mu.input_mouse_down(
                &state.ui_context,
                i32(event.button.x),
                i32(event.button.y),
                btn
            )
        } else {
            mu.input_mouse_up(
                &state.ui_context,
                i32(event.button.x),
                i32(event.button.y),
                btn
            )
        }
    case .MOUSE_WHEEL:
        if state.ui_context.hover_root != nil {
            mu.input_scroll(&state.ui_context, 0, i32(event.wheel.y * -30))
        }
    case .TEXT_INPUT:
        on_microui_text_input(event, state)
    case .KEY_DOWN, .KEY_UP:
        k, ok := KEY_MAP[event.key.key]
        if !ok {
            break
        }
        if event.type == .KEY_DOWN {
            mu.input_key_down(&state.ui_context, k)
        } else {
            mu.input_key_up(&state.ui_context, k)
        }

        if .CTRL in state.ui_context.key_down_bits {
            break
        }
    }

    // Fractal input handling
    #partial switch event.type {
    case .QUIT, .WINDOW_CLOSE_REQUESTED:
        return .SUCCESS
    case .KEY_DOWN:
        handle_fractal_keyboard_input(state, event.key.key)
    case .MOUSE_WHEEL:
        if state.ui_context.hover_root == nil {
            handle_fractal_zoom(state, event)
        }
    case .MOUSE_BUTTON_UP:
        if event.button.button == sdl.BUTTON_LEFT {
            result := end_fractal_drag(state)
            if result != .CONTINUE {
                return result
            }
        }
    case .MOUSE_BUTTON_DOWN:
        if event.button.button == sdl.BUTTON_LEFT {
            result := start_fractal_drag(state)
            if result != .CONTINUE {
                return result
            }
        }
    case .MOUSE_MOTION:
        handle_fractal_drag(state, event)
    case .WINDOW_PIXEL_SIZE_CHANGED:
        e := event.window
        state.window_width = u32(e.data1)
        state.window_height = u32(e.data2)
        state.fractal.uniform.resolution = { f32(e.data1), f32(e.data2) }

        sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.texture)
        state.gpu.texture = create_output_texture(
            state.gpu.device,
            state.window_width,
            state.window_height
        )
    }

    return .CONTINUE
}

@(export)
SDL_AppIterate :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    state := (^AppState)(appstate)
    context = state.ctx
    defer free_all(context.temp_allocator)

    @static opts := mu.Options{.NO_CLOSE}

    mu.begin(&state.ui_context)
    if mu.begin_window(&state.ui_context, "Controls", mu.Rect{10, 10, UI_CONTROL_WINDOW_WIDTH, UI_CONTROL_WINDOW_HEIGHT}, opts) {
        container := mu.get_current_container(&state.ui_context)
        padding := state.ui_context.style.padding
        spacing := state.ui_context.style.spacing
        available := container.body.w - padding * 2

        if .ACTIVE in mu.header(&state.ui_context, "Zoom and Pan", {.EXPANDED}) {
            mu.layout_row(&state.ui_context, {60, -1}, 0)

            mu.label(&state.ui_context, "Zoom:")
            zoom_format := state.fractal.uniform.zoom > 1_000_000 || state.fractal.uniform.zoom < 0.000_001 ? "%e" : "%.4f"
            mu.label(&state.ui_context, fmt.tprintf(zoom_format, state.fractal.uniform.zoom))

            if state.ui_context.hover_root == nil {
                mouse_x, mouse_y : f32
                _ = sdl.GetMouseState(&mouse_x, &mouse_y)

                complex_coords := screen_to_complex(
                    mouse_x,
                    mouse_y,
                    state.window_width,
                    state.window_height,
                    state.fractal.uniform.center,
                    state.fractal.uniform.zoom
                )

                mu.label(&state.ui_context, "Re:")
                mu.label(&state.ui_context, fmt.tprintf("%.6f", real(complex_coords)))

                mu.label(&state.ui_context, "Im:")
                mu.label(&state.ui_context, fmt.tprintf("%.6f", imag(complex_coords)))
            } else {
                mu.label(&state.ui_context, "Re:")
                mu.label(&state.ui_context, "--")
                mu.label(&state.ui_context, "Im:")
                mu.label(&state.ui_context, "--")
            }

            mu.layout_row(&state.ui_context, {available / 3, -1}, 0)
            mu.label(&state.ui_context, "Iterations:")
            max_iter_float := f32(state.fractal.uniform.max_iter)
            mu.slider(&state.ui_context, &max_iter_float, 8, 1024, 1)
            state.fractal.uniform.max_iter = i32(max_iter_float)

            mu.layout_row(&state.ui_context, {-1}, 0)
            if .SUBMIT in mu.button(&state.ui_context, "Reset View") {
                reset_fractal_view(&state.fractal.uniform, &state.fractal.zoom_level)
            }
        }

        if .ACTIVE in mu.header(&state.ui_context, "Palette") {
            mu.layout_row(&state.ui_context, {-1}, 12)
            swatch_rect := mu.layout_next(&state.ui_context)

            step_w := f32(swatch_rect.w) / f32(PALETTE_SWATCH_STEPS)

            for i in 0..<PALETTE_SWATCH_STEPS {
                t := f32(i) / f32(PALETTE_SWATCH_STEPS - 1)
                color := cosine_palette_cpu(
                    t,
                    state.fractal.uniform.palette_a,
                    state.fractal.uniform.palette_b,
                    state.fractal.uniform.palette_c,
                    state.fractal.uniform.palette_d,
                )
                slice := mu.Rect{
                    x = swatch_rect.x + i32(f32(i) * step_w),
                    y = swatch_rect.y,
                    w = i32(math.ceil(step_w)) + 1,
                    h = swatch_rect.h,
                }
                mu.draw_rect(&state.ui_context, slice, mu.Color{
                    r = u8(math.clamp(color.r, 0, 1) * 255),
                    g = u8(math.clamp(color.g, 0, 1) * 255),
                    b = u8(math.clamp(color.b, 0, 1) * 255),
                    a = 255,
                })
            }

            palette_row(&state.ui_context, "a:", &state.fractal.uniform.palette_a)
            palette_row(&state.ui_context, "b:", &state.fractal.uniform.palette_b)
            palette_row(&state.ui_context, "c:", &state.fractal.uniform.palette_c)
            palette_row(&state.ui_context, "d:", &state.fractal.uniform.palette_d)
        }

        if .ACTIVE in mu.header(&state.ui_context, "Presets") {
            button_w  := available - PALETTE_SWATCH_WIDTH - spacing

            for preset in palette_presets {
                mu.layout_row(&state.ui_context, {button_w, PALETTE_SWATCH_WIDTH}, 0)

                if .SUBMIT in mu.button(&state.ui_context, preset.name) {
                    apply_palette_preset(&state.fractal.uniform, preset)
                }

                swatch_container_rect := mu.layout_next(&state.ui_context)
                step_w := f32(swatch_container_rect.w) / PALETTE_PRESET_SWATCH_STEPS
                for i in 0..<PALETTE_PRESET_SWATCH_STEPS {
                    t := f32(i) / f32(PALETTE_PRESET_SWATCH_STEPS - 1)
                    color := cosine_palette_cpu(t, preset.a, preset.b, preset.c, preset.d)
                    slice_rect := mu.Rect{
                        x = swatch_container_rect.x + i32(f32(i) * step_w),
                        y = swatch_container_rect.y,
                        w = i32(math.ceil(step_w)) + 1,
                        h = swatch_container_rect.h,
                    }
                    mu.draw_rect(&state.ui_context, slice_rect, mu.Color{
                        r = u8(math.clamp(color.r, 0, 1) * 255),
                        g = u8(math.clamp(color.g, 0, 1) * 255),
                        b = u8(math.clamp(color.b, 0, 1) * 255),
                        a = 255,
                    })
                }
            }
        }

        mu.end_window(&state.ui_context)
    }
    mu.end(&state.ui_context)

    vertex_count := 0
    vertices_ptr := (^UIVertex)(sdl.MapGPUTransferBuffer(state.gpu.device, state.gpu.ui_transfer_buffer, false))
    vertices := ([^]UIVertex)(vertices_ptr)[:MAX_UI_VERTICES]

    cmd_iter : ^mu.Command
    for mu.next_command(&state.ui_context, &cmd_iter) {
        #partial switch cmd in cmd_iter.variant {
            case ^mu.Command_Rect:
                push_rect(
                    &vertices,
                    &vertex_count,
                    cmd.rect,
                    {0, 0, 0, 0},
                    cmd.color,
                )
            case ^mu.Command_Text:
                for ch in cmd.str {
                    if ch < 32 || int(ch) >= 128 do continue
                    src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + int(ch)]
                    dst := mu.Rect{cmd.pos.x, cmd.pos.y, src.w, src.h}
                    push_rect_uv(&vertices, &vertex_count, dst, src, cmd.color)
                    cmd.pos.x += src.w
                }
            case ^mu.Command_Icon:
                src := mu.default_atlas[cmd.id]
                x := cmd.rect.x + (cmd.rect.w - src.w) / 2
                y := cmd.rect.y + (cmd.rect.h - src.h) / 2
                push_rect_uv(
                    &vertices,
                    &vertex_count,
                    mu.Rect{x, y, src.w, src.h},
                    src,
                    cmd.color
                )
        }
    }
    sdl.UnmapGPUTransferBuffer(state.gpu.device, state.gpu.ui_transfer_buffer)

    command_buffer := sdl.AcquireGPUCommandBuffer(state.gpu.device)

    storageTextureBindings := [1]sdl.GPUStorageTextureReadWriteBinding{
        { texture = state.gpu.texture }
    }
    computePass := sdl.BeginGPUComputePass(
        command_buffer,
        raw_data(storageTextureBindings[:]),
        1,
        nil,
        0
    )
    sdl.BindGPUComputePipeline(computePass, state.gpu.compute_pipeline)
    sdl.PushGPUComputeUniformData(
        command_buffer,
        0,
        &state.fractal.uniform,
        size_of(FractalUniform)
    )
    sdl.DispatchGPUCompute(
        computePass,
        (state.window_width + 7) / 8,
        (state.window_height + 7) / 8,
        1
    )
    sdl.EndGPUComputePass(computePass)

    if vertex_count > 0 {
        ui_copy_pass := sdl.BeginGPUCopyPass(command_buffer)
        sdl.UploadToGPUBuffer(
            ui_copy_pass,
            sdl.GPUTransferBufferLocation{ transfer_buffer = state.gpu.ui_transfer_buffer },
            sdl.GPUBufferRegion{
                buffer = state.gpu.ui_vertex_buffer,
                size   = u32(vertex_count * size_of(UIVertex)),
            },
            false,
        )
        sdl.EndGPUCopyPass(ui_copy_pass)
    }

    swapchainTexture: ^sdl.GPUTexture
    width, height: u32

    ok := sdl.WaitAndAcquireGPUSwapchainTexture(
        command_buffer,
        state.window,
        &swapchainTexture,
        &width,
        &height
    )
    if !ok {
        log.errorf("unable to acquire swapchain texture: %s", sdl.GetError())
        return .FAILURE
    }
    if swapchainTexture == nil {
        ok = sdl.SubmitGPUCommandBuffer(command_buffer)
        if !ok {
            log.errorf("unable to submit GPU command buffer: %s", sdl.GetError())
            return .FAILURE
        }
        return .CONTINUE
    }

    sdl.BlitGPUTexture(command_buffer, sdl.GPUBlitInfo{
        source = {
            texture = state.gpu.texture,
            w = state.window_width, h = state.window_height,
            mip_level = 0, layer_or_depth_plane = 0,
            x = 0, y = 0,
        },
        destination = {
            texture = swapchainTexture,
            w = width, h = height,
            mip_level = 0, layer_or_depth_plane = 0,
            x = 0, y = 0,
        },
        load_op = .DONT_CARE,
        filter  = .LINEAR,
    })

    if vertex_count > 0 {
        color_target := sdl.GPUColorTargetInfo{
            texture  = swapchainTexture,
            load_op  = .LOAD,
            store_op = .STORE,
        }
        render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target, 1, nil)
        sdl.BindGPUGraphicsPipeline(render_pass, state.gpu.ui_pipeline)

        globals := UIGlobals{ screen_size = { f32(width), f32(height) }}
        sdl.PushGPUVertexUniformData(command_buffer, 0, &globals, size_of(UIGlobals))

        buf_binding := [1]sdl.GPUBufferBinding{{ buffer = state.gpu.ui_vertex_buffer }}
        sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(buf_binding[:]), 1)

        tex_binding := [1]sdl.GPUTextureSamplerBinding{{
            texture = state.gpu.ui_font_texture,
            sampler = state.gpu.ui_font_sampler,
        }}
        sdl.BindGPUFragmentSamplers(render_pass, 0, raw_data(tex_binding[:]), 1)

        sdl.DrawGPUPrimitives(render_pass, u32(vertex_count), 1, 0, 0)
        sdl.EndGPURenderPass(render_pass)
    }

    ok = sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {
        log.errorf("unable to submit GPU command buffer: %s", sdl.GetError())
        return .FAILURE
    }

    return .CONTINUE
}

@(export)
SDL_AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    state := (^AppState)(appstate)
    context = state.ctx

    sdl.DestroyCursor(state.fractal.move_cursor)
    sdl.DestroyCursor(state.fractal.default_cursor)

    sdl.ReleaseGPUBuffer(state.gpu.device, state.gpu.ui_vertex_buffer)
    sdl.ReleaseGPUTransferBuffer(state.gpu.device, state.gpu.ui_transfer_buffer)
    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.ui_font_texture)
    sdl.ReleaseGPUSampler(state.gpu.device, state.gpu.ui_font_sampler)
    sdl.ReleaseGPUGraphicsPipeline(state.gpu.device, state.gpu.ui_pipeline)

    sdl.ReleaseGPUTexture(state.gpu.device, state.gpu.texture)
    sdl.ReleaseGPUComputePipeline(state.gpu.device, state.gpu.compute_pipeline)

    sdl.DestroyGPUDevice(state.gpu.device)
    sdl.DestroyWindow(state.window)
    sdl.Quit()

    log.destroy_console_logger(context.logger)
    free(state)
}
