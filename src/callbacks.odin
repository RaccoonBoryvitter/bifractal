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
    context.logger = log.create_console_logger()

    state := new(AppState)
    state.ctx = context

    appstate^ = rawptr(state)

    ok := sdl.Init({.VIDEO, .EVENTS})
    if !ok {
        log.errorf("unable to initialize SDL: %s", sdl.GetError())
        return .FAILURE
    }

    window := sdl.CreateWindow("Odin Zoom", 1280, 720, {.RESIZABLE, .HIGH_PIXEL_DENSITY})
    if window == nil {
        log.errorf("unable to create SDL window: %s", sdl.GetError())
        return .FAILURE
    }
    state.window = window
    
    gpu_device := sdl.CreateGPUDevice({.SPIRV}, true, nil)
    if gpu_device == nil {
        log.errorf("unable to create SDL GPU device: %s", sdl.GetError())
        return .FAILURE
    }
    state.device = gpu_device

    ok = sdl.ClaimWindowForGPUDevice(state.device, state.window)
    if !ok {
        log.errorf("unable to claim window for GPU device: %s", sdl.GetError())
        return .FAILURE
    }

    compute_pipeline := create_compute_pipeline("../assets/shaders/compiled/mandelbrot.spv", state.device)
    if compute_pipeline == nil {
        log.errorf("unable to create GPU compute pipeline: %s", sdl.GetError())
        return .FAILURE
    }
    state.compute_pipeline = compute_pipeline

    sdl.GetWindowSizeInPixels(
        state.window,
        (^i32)(&state.window_width),
        (^i32)(&state.window_height),
    )

    state.texture = create_output_texture(state.device, state.window_width, state.window_height)

    state.uniform = FractalUniform{
        center = { -0.5, 0.0 },
        zoom = 0.5,
        max_iter = 256,
        resolution = { f32(state.window_width), f32(state.window_height) },
        palette_a  = { 0.5, 0.5, 0.5 },
        palette_b  = { 0.5, 0.5, 0.5 },
        palette_c  = { 1.0, 1.0, 1.0 },
        palette_d  = { 0.0, 0.10, 0.20 },
    }
    state.zoom_level = math.log2(state.uniform.zoom)

    state.default_cursor = sdl.CreateSystemCursor(.DEFAULT)
    state.move_cursor = sdl.CreateSystemCursor(.MOVE)

    ui_vertex_shader := create_gpu_shader(
        state.device,
        "../assets/shaders/compiled/ui.vert.spv",
        .VERTEX,
        num_uniform_buffers = 1
    )
    if ui_vertex_shader == nil {
        return .FAILURE
    }

    ui_fragment_shader := create_gpu_shader(
        state.device,
        "../assets/shaders/compiled/ui.frag.spv",
        .FRAGMENT,
        num_samplers = 1
    )
    if ui_fragment_shader == nil {
        return .FAILURE
    }

    ui_vertex_buffer_descs := [1]sdl.GPUVertexBufferDescription{{
        slot = 0,
        pitch = size_of(UIVertex),
        input_rate = .VERTEX,
    }}

    ui_vertex_attrs := [3]sdl.GPUVertexAttribute{
        { location = 0, buffer_slot = 0, format = .FLOAT2, offset = 0 },
        { location = 1, buffer_slot = 0, format = .FLOAT2, offset = size_of(f32) * 2 },
        { location = 2, buffer_slot = 0, format = .FLOAT4, offset = size_of(f32) * 4 },
    }

    color_targets := [1]sdl.GPUColorTargetDescription{{
        format = sdl.GetGPUSwapchainTextureFormat(state.device, state.window),
        blend_state = {
            enable_blend = true,
            color_blend_op = .ADD,
            alpha_blend_op = .ADD,
            src_color_blendfactor = .SRC_ALPHA,
            dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
            src_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
            dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
        },
    }}

    ui_pipeline := sdl.CreateGPUGraphicsPipeline(
        state.device,
        sdl.GPUGraphicsPipelineCreateInfo{
            vertex_shader = ui_vertex_shader,
            fragment_shader = ui_fragment_shader,
            primitive_type = .TRIANGLELIST,
            vertex_input_state = {
                num_vertex_buffers = 1,
                vertex_buffer_descriptions = raw_data(ui_vertex_buffer_descs[:]),
                num_vertex_attributes = 3,
                vertex_attributes = raw_data(ui_vertex_attrs[:]),
            },
            target_info = {
                num_color_targets = 1,
                color_target_descriptions = raw_data(color_targets[:])
            },

        }
    )
    sdl.ReleaseGPUShader(state.device, ui_vertex_shader)
    sdl.ReleaseGPUShader(state.device, ui_fragment_shader)
    state.ui_pipeline = ui_pipeline

    state.ui_vertex_buffer = sdl.CreateGPUBuffer(
        state.device,
        sdl.GPUBufferCreateInfo{
            size = size_of(UIVertex) * MAX_UI_VERTICES,
            usage = {.VERTEX},
        }
    )
    state.ui_transfer_buffer = sdl.CreateGPUTransferBuffer(
        state.device,
        sdl.GPUTransferBufferCreateInfo{
            size = size_of(UIVertex) * MAX_UI_VERTICES,
            usage = .UPLOAD
        }
    )

    state.ui_font_texture = create_font_texture(state.device)
    state.ui_font_sampler = sdl.CreateGPUSampler(
        state.device,
        sdl.GPUSamplerCreateInfo{
            min_filter = .NEAREST,
            mag_filter = .NEAREST,
        }
    )

    mu.init(&state.ui_context)
    state.ui_context.text_width = mu.default_atlas_text_width
    state.ui_context.text_height = mu.default_atlas_text_height

    return .CONTINUE
}

@(export)
SDL_AppEvent :: proc "c" (
    appstate: rawptr,
    event: ^sdl.Event,
) -> sdl.AppResult {
    state := (^AppState)(appstate)
    context = state.ctx

    // UI part
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

    // Fractal part
    #partial switch event.type {
    case .QUIT, .WINDOW_CLOSE_REQUESTED:
        return .SUCCESS
    case .KEY_DOWN:
        keycode := event.key.key
        pan_factor : f32 = 0.05
        if keycode == sdl.K_W {
            state.uniform.center.y -= pan_factor / state.uniform.zoom
        }
        if keycode == sdl.K_S {
            state.uniform.center.y += pan_factor / state.uniform.zoom
        }
        if keycode == sdl.K_A {
            state.uniform.center.x -= pan_factor / state.uniform.zoom
        }
        if keycode == sdl.K_D {
            state.uniform.center.x += pan_factor / state.uniform.zoom
        }

        if keycode == sdl.K_Q {
            state.uniform.max_iter -= 10
            if state.uniform.max_iter < 8 {
                state.uniform.max_iter = 8
            }
        }
        if keycode == sdl.K_E {
            state.uniform.max_iter += 8
            if state.uniform.max_iter > 1024 {
                state.uniform.max_iter = 1024
            }
        }

        if keycode == sdl.K_R {
            state.uniform.zoom = 0.5
            state.zoom_level = math.log2(state.uniform.zoom)

            state.uniform.center = { -0.5, 0.0 }
            state.uniform.max_iter = 256
        }
    case .MOUSE_WHEEL:
        if state.ui_context.hover_root != nil {
            break
        }
        mouse_x, mouse_y : f32
        _ = sdl.GetMouseState(&mouse_x, &mouse_y)

        w := f32(state.window_width)
        h := f32(state.window_height)
        mouse_complex := [2]f32{
            (mouse_x - w * 0.5) / (h * state.uniform.zoom) + state.uniform.center.x,
            (mouse_y - h * 0.5) / (h * state.uniform.zoom) + state.uniform.center.y,
        }

        state.zoom_level += event.wheel.y * 0.1
        state.uniform.zoom = math.exp(state.zoom_level)

        new_mouse_complex := [2]f32{
            (mouse_x - w * 0.5) / (h * state.uniform.zoom) + state.uniform.center.x,
            (mouse_y - h * 0.5) / (h * state.uniform.zoom) + state.uniform.center.y,
        }

        state.uniform.center.x += mouse_complex.x - new_mouse_complex.x
        state.uniform.center.y += mouse_complex.y - new_mouse_complex.y
    case .MOUSE_BUTTON_UP:
        if event.button.button == sdl.BUTTON_LEFT {
			state.is_dragging = false
            ok := sdl.SetCursor(state.default_cursor)
            if !ok {
                log.errorf("unable to set default cursor: %s", sdl.GetError())
                return .FAILURE
            }
		}
    case .MOUSE_BUTTON_DOWN:
        if event.button.button == sdl.BUTTON_LEFT && state.ui_context.hover_root == nil {
			state.is_dragging = true
            ok := sdl.SetCursor(state.move_cursor)
            if !ok {
                log.errorf("unable to set move cursor: %s", sdl.GetError())
                return .FAILURE
            }
		}
    case .MOUSE_MOTION:
        if !state.is_dragging || state.ui_context.hover_root != nil {
            break
        }

        dx := f32(event.motion.xrel)
        dy := f32(event.motion.yrel)
        scale := 2.0 / (f32(state.window_height) * state.uniform.zoom)

        state.uniform.center.x -= dx * scale 
        state.uniform.center.y -= dy * scale
    case .WINDOW_PIXEL_SIZE_CHANGED:
        e := event.window
        state.window_width = u32(e.data1)
        state.window_height = u32(e.data2)
        state.uniform.resolution = { f32(e.data1), f32(e.data2) }

        sdl.ReleaseGPUTexture(state.device, state.texture)
        state.texture = create_output_texture(
            state.device,
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
    if mu.begin_window(&state.ui_context, "Controls", mu.Rect{10, 10, 360, 200}, opts) {
        container := mu.get_current_container(&state.ui_context)
        padding := state.ui_context.style.padding
        spacing := state.ui_context.style.spacing
        available := container.body.w - padding * 2

        if .ACTIVE in mu.header(&state.ui_context, "Zoom and Pan", {.EXPANDED}) {
			mu.layout_row(&state.ui_context, {60, -1}, 0)

            mu.label(&state.ui_context, "Zoom:")
            zoom_format := state.uniform.zoom > 1_000_000 || state.uniform.zoom < 0.000_001 ? "%e" : "%.4f"
            mu.label(&state.ui_context, fmt.tprintf(zoom_format, state.uniform.zoom))

            if state.ui_context.hover_root == nil {
                mouse_x, mouse_y : f32
                _ = sdl.GetMouseState(&mouse_x, &mouse_y)

                complex_coords := screen_to_complex(
                    mouse_x,
                    mouse_y,
                    state.window_width,
                    state.window_height,
                    state.uniform.center,
                    state.uniform.zoom
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
            max_iter_float := f32(state.uniform.max_iter)
            mu.slider(&state.ui_context, &max_iter_float, 8, 1024, 1)
            state.uniform.max_iter = i32(max_iter_float)

            mu.layout_row(&state.ui_context, {-1}, 0)
            if .SUBMIT in mu.button(&state.ui_context, "Reset View") {
                state.uniform.zoom = 0.5
                state.zoom_level = math.log2(state.uniform.zoom)

                state.uniform.center = { -0.5, 0.0 }
                state.uniform.max_iter = 256
            }            
        }

        if .ACTIVE in mu.header(&state.ui_context, "Palette") {
            mu.layout_row(&state.ui_context, {-1}, 12)
            swatch_rect := mu.layout_next(&state.ui_context)

            STEPS :: 64
            step_w := f32(swatch_rect.w) / f32(STEPS)

            for i in 0..<STEPS {
                t := f32(i) / f32(STEPS - 1)
                color := cosine_palette_cpu(
                    t,
                    state.uniform.palette_a,
                    state.uniform.palette_b,
                    state.uniform.palette_c,
                    state.uniform.palette_d,
                )
                slice := mu.Rect{
                    x = swatch_rect.x + i32(f32(i) * step_w),
                    y = swatch_rect.y,
                    w = i32(math.ceil(step_w)) + 1,  // +1 to avoid gaps between slices
                    h = swatch_rect.h,
                }
                mu.draw_rect(&state.ui_context, slice, mu.Color{
                    r = u8(math.clamp(color.r, 0, 1) * 255),
                    g = u8(math.clamp(color.g, 0, 1) * 255),
                    b = u8(math.clamp(color.b, 0, 1) * 255),
                    a = 255,
                })
            }

			palette_row(&state.ui_context, "a:", &state.uniform.palette_a)
            palette_row(&state.ui_context, "b:", &state.uniform.palette_b)
            palette_row(&state.ui_context, "c:", &state.uniform.palette_c)
            palette_row(&state.ui_context, "d:", &state.uniform.palette_d)
        }

        if .ACTIVE in mu.header(&state.ui_context, "Presets") {
            SWATCH_W  :: 64
            button_w  := available - SWATCH_W - spacing

            for preset in palette_presets {
                mu.layout_row(&state.ui_context, {button_w, SWATCH_W}, 0)

                if .SUBMIT in mu.button(&state.ui_context, preset.name) {
                    apply_palette_preset(&state.uniform, preset)
                }

                swatch_container_rect := mu.layout_next(&state.ui_context)
                STEPS :: 16
                step_w := f32(swatch_container_rect.w) / STEPS
                for i in 0..<STEPS {
                    t := f32(i) / f32(STEPS - 1)
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
    vertices_ptr := (^UIVertex)(sdl.MapGPUTransferBuffer(state.device, state.ui_transfer_buffer, false))
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
                    cmd.color
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
    sdl.UnmapGPUTransferBuffer(state.device, state.ui_transfer_buffer)

    command_buffer := sdl.AcquireGPUCommandBuffer(state.device)

    storageTextureBindings := [1]sdl.GPUStorageTextureReadWriteBinding{
        { texture = state.texture }
    }
    computePass := sdl.BeginGPUComputePass(
        command_buffer,
        raw_data(storageTextureBindings[:]),
        1,
        nil,
        0
    )
    sdl.BindGPUComputePipeline(computePass, state.compute_pipeline)
    sdl.PushGPUComputeUniformData(
        command_buffer,
        0,
        &state.uniform,
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
            sdl.GPUTransferBufferLocation{ transfer_buffer = state.ui_transfer_buffer },
            sdl.GPUBufferRegion{
                buffer = state.ui_vertex_buffer,
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
            texture = state.texture,
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
        sdl.BindGPUGraphicsPipeline(render_pass, state.ui_pipeline)

        globals := UIGlobals{ screen_size = { f32(width), f32(height) }}
        sdl.PushGPUVertexUniformData(command_buffer, 0, &globals, size_of(UIGlobals))

        buf_binding := [1]sdl.GPUBufferBinding{{ buffer = state.ui_vertex_buffer }}
        sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(buf_binding[:]), 1)

        tex_binding := [1]sdl.GPUTextureSamplerBinding{{
            texture = state.ui_font_texture,
            sampler = state.ui_font_sampler,
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
    // Probably, the result should be handled somehow?
    // Like, if it's a failure, then we just output the error?
    // I don't know, but let's ignore it for now
    state := (^AppState)(appstate)

    sdl.DestroyCursor(state.move_cursor)
    sdl.DestroyCursor(state.default_cursor)

    sdl.ReleaseGPUBuffer(state.device, state.ui_vertex_buffer)
    sdl.ReleaseGPUTransferBuffer(state.device, state.ui_transfer_buffer)
    sdl.ReleaseGPUTexture(state.device, state.ui_font_texture)
    sdl.ReleaseGPUSampler(state.device, state.ui_font_sampler)
    sdl.ReleaseGPUGraphicsPipeline(state.device, state.ui_pipeline)

    sdl.ReleaseGPUTexture(state.device, state.texture)
    sdl.ReleaseGPUComputePipeline(state.device, state.compute_pipeline)

    sdl.DestroyGPUDevice(state.device)
    sdl.DestroyWindow(state.window)
    sdl.Quit()

    context = state.ctx
    log.destroy_console_logger(context.logger)

    // I don't know if I should clean it like this, but why not?
    state = nil
}
