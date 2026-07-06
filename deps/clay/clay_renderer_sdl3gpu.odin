package clay

import "base:runtime"
import "core:math"

import sdl "vendor:sdl3"

NUM_CIRCLE_SEGMENTS :: 16

Renderer_Vertex :: struct {
    position: [2]f32,
    uv:       [2]f32,
    color:    [4]f32,
}

Renderer_Globals :: struct {
    screen_size: [2]f32,
}

MAX_BATCHES :: 256

Renderer_Batch :: struct {
    vertex_start: i32,
    vertex_count: i32,
    scissor:      sdl.Rect,
    has_scissor:  bool,
}

Renderer_Text_Callback :: proc "c" (
    data: ^Renderer_Data,
    text: StringSlice,
    config: ^TextRenderData,
    bounding_box: BoundingBox,
    push_glyph_quad: proc "c" (
        data: ^Renderer_Data,
        dst: BoundingBox,
        uv_min, uv_max: [2]f32,
        color: [4]f32,
    ),
)

Renderer_Data :: struct {
    device:          ^sdl.GPUDevice,
    window:          ^sdl.Window,
    pipeline:        ^sdl.GPUGraphicsPipeline,
    vertex_buffer:   ^sdl.GPUBuffer,
    transfer_buffer: ^sdl.GPUTransferBuffer,
    font_texture:    ^sdl.GPUTexture,
    font_sampler:    ^sdl.GPUSampler,
    max_vertices:    i32,
    batches:         [dynamic]Renderer_Batch,
    vertex_count:    i32,
    mapped_vertices: [^]Renderer_Vertex,
    text_callback:   Renderer_Text_Callback,
    text_user_data:  rawptr,
    current_scissor: sdl.Rect,
    scissor_active:  bool,
}

external_init_renderer :: proc(
    device: ^sdl.GPUDevice,
    window: ^sdl.Window,
    pipeline: ^sdl.GPUGraphicsPipeline,
    max_vertices: i32,
    font_texture: ^sdl.GPUTexture,
    font_sampler: ^sdl.GPUSampler,
    max_batches: i32 = MAX_BATCHES,
    text_callback: Renderer_Text_Callback = nil,
    text_user_data: rawptr = nil,
) -> ^Renderer_Data {
    vertex_buffer := sdl.CreateGPUBuffer(
        device,
        sdl.GPUBufferCreateInfo {
            size = u32(max_vertices * size_of(Renderer_Vertex)),
            usage = {.VERTEX},
        },
    )
    if vertex_buffer == nil do return nil
    transfer_buffer := sdl.CreateGPUTransferBuffer(
        device,
        sdl.GPUTransferBufferCreateInfo {
            size = u32(max_vertices * size_of(Renderer_Vertex)),
            usage = .UPLOAD,
        },
    )
    if transfer_buffer == nil {
        sdl.ReleaseGPUBuffer(device, vertex_buffer)
        return nil
    }

    data := new(Renderer_Data)
    data^ = {
        device          = device,
        window          = window,
        pipeline        = pipeline,
        vertex_buffer   = vertex_buffer,
        transfer_buffer = transfer_buffer,
        font_texture    = font_texture,
        font_sampler    = font_sampler,
        max_vertices    = max_vertices,
        batches         = make([dynamic]Renderer_Batch, 0, u32(max_batches)),
        text_callback   = text_callback,
        text_user_data  = text_user_data,
    }
    return data
}

external_destroy_renderer :: proc(data: ^Renderer_Data) {
    if data == nil do return
    if data.vertex_buffer != nil do sdl.ReleaseGPUBuffer(data.device, data.vertex_buffer)
    if data.transfer_buffer != nil do sdl.ReleaseGPUTransferBuffer(data.device, data.transfer_buffer)
    delete(data.batches)
    free(data)
}

external_begin_frame :: proc(data: ^Renderer_Data) {
    if data == nil do return
    data.vertex_count = 0
    data.scissor_active = false
    clear(&data.batches)
    data.mapped_vertices = ([^]Renderer_Vertex)(
        sdl.MapGPUTransferBuffer(data.device, data.transfer_buffer, false),
    )
    flush_batch(data)
}

external_end_frame :: proc(
    data: ^Renderer_Data,
    command_buffer: ^sdl.GPUCommandBuffer,
    swapchain_texture: ^sdl.GPUTexture,
    width, height: u32,
    upload: bool = true,
    load_op: sdl.GPULoadOp = .LOAD,
) {
    if data == nil do return
    if data.mapped_vertices != nil {
        sdl.UnmapGPUTransferBuffer(data.device, data.transfer_buffer)
        data.mapped_vertices = nil
    }
    if data.vertex_count <= 0 do return
    if len(data.batches) == 0 do return

    if upload {
        copy_pass := sdl.BeginGPUCopyPass(command_buffer)
        sdl.UploadToGPUBuffer(
            copy_pass,
            sdl.GPUTransferBufferLocation {
                transfer_buffer = data.transfer_buffer,
            },
            sdl.GPUBufferRegion {
                buffer = data.vertex_buffer,
                size = u32(data.vertex_count * size_of(Renderer_Vertex)),
            },
            false,
        )
        sdl.EndGPUCopyPass(copy_pass)
    }

    color_target := sdl.GPUColorTargetInfo {
        texture  = swapchain_texture,
        load_op  = load_op,
        store_op = .STORE,
    }
    render_pass := sdl.BeginGPURenderPass(
        command_buffer,
        &color_target,
        1,
        nil,
    )
    sdl.BindGPUGraphicsPipeline(render_pass, data.pipeline)

    globals := Renderer_Globals {
        screen_size = {f32(width), f32(height)},
    }
    sdl.PushGPUVertexUniformData(
        command_buffer,
        0,
        &globals,
        size_of(Renderer_Globals),
    )

    vertex_binding := [1]sdl.GPUBufferBinding{{buffer = data.vertex_buffer}}
    sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(vertex_binding[:]), 1)

    if data.font_texture != nil {
        tex_binding := [1]sdl.GPUTextureSamplerBinding {
            {texture = data.font_texture, sampler = data.font_sampler},
        }
        sdl.BindGPUFragmentSamplers(
            render_pass,
            0,
            raw_data(tex_binding[:]),
            1,
        )
    }

    full_rect := sdl.Rect {
        x = 0,
        y = 0,
        w = i32(width),
        h = i32(height),
    }
    last_scissor_active: bool = false
    last_scissor: sdl.Rect = {}
    for i in 0 ..< len(data.batches) {
        b := &data.batches[i]
        if b.has_scissor {
            if !last_scissor_active || b.scissor != last_scissor {
                sdl.SetGPUScissor(render_pass, b.scissor)
                last_scissor = b.scissor
                last_scissor_active = true
            }
        }
         else {
            if last_scissor_active {
                sdl.SetGPUScissor(render_pass, full_rect)
                last_scissor_active = false
            }
        }
        if b.vertex_count > 0 {
            sdl.DrawGPUPrimitives(
                render_pass,
                u32(b.vertex_count),
                1,
                u32(b.vertex_start),
                0,
            )
        }
    }

    sdl.EndGPURenderPass(render_pass)
}

external_render_commands :: proc(
    data: ^Renderer_Data,
    commands: ^ClayArray(RenderCommand),
) {
    if data == nil do return
    for i in 0 ..< i32(commands.length) {
        command := RenderCommandArray_Get(commands, i)
        bound_box := command.boundingBox
        rect := bounding_box_to_sdl_frect(bound_box)
        #partial switch command.commandType {
        case .Rectangle:
            cfg := &command.renderData.rectangle
            c := color_to_f32(cfg.backgroundColor)
            if cfg.cornerRadius.topLeft > 0 {
                push_rounded_rect(data, rect, cfg.cornerRadius.topLeft, c)
            }
             else {
                push_rect(data, rect, c)
            }
        case .Border:
            render_border(data, rect, &command.renderData.border)
        case .ScissorStart:
            data.scissor_active = true
            data.current_scissor = bounding_box_to_sdl_rect(bound_box)
            flush_batch(data)
        case .ScissorEnd:
            data.scissor_active = false
            flush_batch(data)
        case .Image:
        // Image rendering requires a texture registry via Clay userData.
        // Caller must extend this with per-image GPUTexture + UV lookup.
        case .Text:
            if data.text_callback != nil {
                data.text_callback(
                    data,
                    command.renderData.text.stringContents,
                    &command.renderData.text,
                    bound_box,
                    push_glyph_quad,
                )
            }
        case .OverlayColorStart, .OverlayColorEnd, .Custom, .None:
        }
    }
}

@(private = "file")
bounding_box_to_sdl_rect :: proc(box: BoundingBox) -> sdl.Rect {
    return sdl.Rect {
        x = i32(box.x),
        y = i32(box.y),
        w = i32(box.width),
        h = i32(box.height),
    }
}

@(private = "file")
bounding_box_to_sdl_frect :: proc(box: BoundingBox) -> sdl.FRect {
    return sdl.FRect{x = box.x, y = box.y, w = box.width, h = box.height}
}

@(private = "file")
color_to_f32 :: proc(c: Color) -> [4]f32 {
    return [4]f32{c[0] / 255.0, c[1] / 255.0, c[2] / 255.0, c[3] / 255.0}
}

@(private = "file")
flush_batch :: proc(data: ^Renderer_Data) {
    n := len(data.batches)
    start :=
        n > 0 ? data.batches[n - 1].vertex_start + data.batches[n - 1].vertex_count : 0
    append(
        &data.batches,
        Renderer_Batch {
            vertex_start = start,
            vertex_count = 0,
            scissor = data.current_scissor,
            has_scissor = data.scissor_active,
        },
    )
}

@(private = "file")
current_batch :: proc(data: ^Renderer_Data) -> ^Renderer_Batch {
    n := len(data.batches)
    assert(n > 0)
    return &data.batches[n - 1]
}

@(private = "file")
push_vertex :: proc(data: ^Renderer_Data, v: Renderer_Vertex) {
    if data.vertex_count >= data.max_vertices do return
    if data.mapped_vertices == nil do return
    data.mapped_vertices[data.vertex_count] = v
    data.vertex_count += 1
    b := current_batch(data)
    b.vertex_count += 1
}

@(private = "file")
push_quad :: proc(
    data: ^Renderer_Data,
    x0, y0, x1, y1: f32,
    u0, v0, u1, v1: f32,
    c: [4]f32,
) {
    push_vertex(data, {{x0, y0}, {u0, v0}, c})
    push_vertex(data, {{x1, y0}, {u1, v0}, c})
    push_vertex(data, {{x1, y1}, {u1, v1}, c})
    push_vertex(data, {{x0, y0}, {u0, v0}, c})
    push_vertex(data, {{x1, y1}, {u1, v1}, c})
    push_vertex(data, {{x0, y1}, {u0, v1}, c})
}

push_rect :: proc(data: ^Renderer_Data, rect: sdl.FRect, c: [4]f32) {
    push_quad(
        data,
        rect.x,
        rect.y,
        rect.x + rect.w,
        rect.y + rect.h,
        0,
        0,
        0,
        0,
        c,
    )
}

push_glyph_quad :: proc "c" (
    data: ^Renderer_Data,
    dst: BoundingBox,
    uv_min: [2]f32,
    uv_max: [2]f32,
    color: [4]f32,
) {
    context = runtime.default_context()
    push_quad(
        data,
        dst.x,
        dst.y,
        dst.x + dst.width,
        dst.y + dst.height,
        uv_min[0],
        uv_min[1],
        uv_max[0],
        uv_max[1],
        color,
    )
}

@(private = "file")
push_triangle_fan :: proc(
    data: ^Renderer_Data,
    p0, p1, p2: [2]f32,
    c: [4]f32,
) {
    dummy := [2]f32{0, 0}
    push_vertex(data, {{p0[0], p0[1]}, dummy, c})
    push_vertex(data, {{p1[0], p1[1]}, dummy, c})
    push_vertex(data, {{p2[0], p2[1]}, dummy, c})
}

@(private = "file")
push_rounded_rect :: proc(
    data: ^Renderer_Data,
    rect: sdl.FRect,
    corner_radius: f32,
    c: [4]f32,
) {
    min_radius := math.min(rect.w, rect.h) / 2.0
    clamped_radius := math.min(corner_radius, min_radius)
    num_segments := math.max(NUM_CIRCLE_SEGMENTS, i32(clamped_radius * 0.5))

    cx := rect.x + clamped_radius
    cy := rect.y + clamped_radius
    center_verts := [4][2]f32 {
        {cx, cy},
        {rect.x + rect.w - clamped_radius, cy},
        {rect.x + rect.w - clamped_radius, rect.y + rect.h - clamped_radius},
        {cx, rect.y + rect.h - clamped_radius},
    }

    step := (math.PI / 2.0) / f32(num_segments)
    for i in 0 ..< num_segments {
        a1 := f32(i) * step
        a2 := (f32(i) + 1.0) * step
        for j in 0 ..< 4 {
            sign_x, sign_y: f32
            switch j {
            case 0:
                sign_x, sign_y = -1.0, -1.0
            case 1:
                sign_x, sign_y = 1.0, -1.0
            case 2:
                sign_x, sign_y = 1.0, 1.0
            case 3:
                sign_x, sign_y = -1.0, 1.0
            }
            cxj := center_verts[j][0]
            cyj := center_verts[j][1]
            p1 := [2]f32 {
                cxj + math.cos(a1) * clamped_radius * sign_x,
                cyj + math.sin(a1) * clamped_radius * sign_y,
            }
            p2 := [2]f32 {
                cxj + math.cos(a2) * clamped_radius * sign_x,
                cyj + math.sin(a2) * clamped_radius * sign_y,
            }
            push_triangle_fan(data, center_verts[j], p1, p2, c)
        }
    }

    push_quad(
        data,
        cx,
        cy,
        rect.x + rect.w - clamped_radius,
        rect.y + rect.h - clamped_radius,
        0,
        0,
        0,
        0,
        c,
    )

    edge_v0 := [4][2]f32 {
        {rect.x + clamped_radius, rect.y},
        {rect.x + rect.w, rect.y + clamped_radius},
        {rect.x + rect.w - clamped_radius, rect.y + rect.h},
        {rect.x, rect.y + rect.h - clamped_radius},
    }
    edge_v1 := [4][2]f32 {
        {rect.x + rect.w - clamped_radius, rect.y},
        {rect.x + rect.w, rect.y + rect.h - clamped_radius},
        {rect.x + clamped_radius, rect.y + rect.h},
        {rect.x, rect.y + clamped_radius},
    }
    for j in 0 ..< 4 {
        push_quad(
            data,
            center_verts[j][0],
            center_verts[j][1],
            edge_v0[j][0],
            edge_v0[j][1],
            0,
            0,
            0,
            0,
            c,
        )
        push_quad(
            data,
            center_verts[j][0],
            center_verts[j][1],
            edge_v1[j][0],
            edge_v1[j][1],
            0,
            0,
            0,
            0,
            c,
        )
    }
}

@(private = "file")
render_border :: proc(
    data: ^Renderer_Data,
    rect: sdl.FRect,
    cfg: ^BorderRenderData,
) {
    min_radius := math.min(rect.w, rect.h) / 2.0
    c := color_to_f32(cfg.color)

    clamped := CornerRadius {
        topLeft     = math.min(cfg.cornerRadius.topLeft, min_radius),
        topRight    = math.min(cfg.cornerRadius.topRight, min_radius),
        bottomLeft  = math.min(cfg.cornerRadius.bottomLeft, min_radius),
        bottomRight = math.min(cfg.cornerRadius.bottomRight, min_radius),
    }

    if cfg.width.left > 0 {
        start_y := rect.y + clamped.topLeft
        length := rect.h - clamped.topLeft - clamped.bottomLeft
        push_rect(
            data,
            sdl.FRect {
                x = rect.x - 1,
                y = start_y,
                w = f32(cfg.width.left),
                h = length,
            },
            c,
        )
    }
    if cfg.width.right > 0 {
        start_x := rect.x + rect.w - f32(cfg.width.right) + 1
        start_y := rect.y + clamped.topRight
        length := rect.h - clamped.topRight - clamped.bottomRight
        push_rect(
            data,
            sdl.FRect {
                x = start_x,
                y = start_y,
                w = f32(cfg.width.right),
                h = length,
            },
            c,
        )
    }
    if cfg.width.top > 0 {
        start_x := rect.x + clamped.topLeft
        length := rect.w - clamped.topLeft - clamped.topRight
        push_rect(
            data,
            sdl.FRect {
                x = start_x,
                y = rect.y - 1,
                w = length,
                h = f32(cfg.width.top),
            },
            c,
        )
    }
    if cfg.width.bottom > 0 {
        start_x := rect.x + clamped.bottomLeft
        start_y := rect.y + rect.h - f32(cfg.width.bottom) + 1
        length := rect.w - clamped.bottomLeft - clamped.bottomRight
        push_rect(
            data,
            sdl.FRect {
                x = start_x,
                y = start_y,
                w = length,
                h = f32(cfg.width.bottom),
            },
            c,
        )
    }

    if cfg.cornerRadius.topLeft > 0 {
        render_arc(
            data,
            rect.x + clamped.topLeft - 1,
            rect.y + clamped.topLeft - 1,
            clamped.topLeft,
            math.PI,
            1.5 * math.PI,
            f32(cfg.width.top),
            c,
        )
    }
    if cfg.cornerRadius.topRight > 0 {
        render_arc(
            data,
            rect.x + rect.w - clamped.topRight,
            rect.y + clamped.topRight - 1,
            clamped.topRight,
            1.5 * math.PI,
            2.0 * math.PI,
            f32(cfg.width.top),
            c,
        )
    }
    if cfg.cornerRadius.bottomLeft > 0 {
        render_arc(
            data,
            rect.x + clamped.bottomLeft - 1,
            rect.y + rect.h - clamped.bottomLeft,
            clamped.bottomLeft,
            0.5 * math.PI,
            math.PI,
            f32(cfg.width.bottom),
            c,
        )
    }
    if cfg.cornerRadius.bottomRight > 0 {
        render_arc(
            data,
            rect.x + rect.w - clamped.bottomRight,
            rect.y + rect.h - clamped.bottomRight,
            clamped.bottomRight,
            0.0,
            0.5 * math.PI,
            f32(cfg.width.bottom),
            c,
        )
    }
}

@(private = "file")
render_arc :: proc(
    data: ^Renderer_Data,
    cx, cy: f32,
    radius: f32,
    start_angle: f32,
    end_angle: f32,
    thickness: f32,
    color: [4]f32,
) {
    num_segments := math.max(NUM_CIRCLE_SEGMENTS, i32(radius * 1.5))
    angle_step := (end_angle - start_angle) / f32(num_segments)
    thickness_step := f32(0.4)
    line_half := f32(0.5) // half-pixel wide line per ring iteration
    dummy_uv := [2]f32{0, 0}

    for t := thickness_step;
        t < thickness - thickness_step;
        t += thickness_step {
        r := math.max(radius - t, f32(1.0))
        prev := [2]f32 {
            f32(i32(math.round_f32(cx + math.cos(start_angle) * r))),
            f32(i32(math.round_f32(cy + math.sin(start_angle) * r))),
        }
        for i in 1 ..< num_segments + 1 {
            a := start_angle + f32(i) * angle_step
            cur := [2]f32 {
                f32(i32(math.round_f32(cx + math.cos(a) * r))),
                f32(i32(math.round_f32(cy + math.sin(a) * r))),
            }
            dx := cur[0] - prev[0]
            dy := cur[1] - prev[1]
            len_sq := dx * dx + dy * dy
            inv_len := len_sq > 0 ? f32(1.0) / math.sqrt_f32(len_sq) : f32(0.0)
            nx := -dy * inv_len * line_half
            ny := dx * inv_len * line_half
            p_out_a := [2]f32{prev[0] + nx, prev[1] + ny}
            p_out_b := [2]f32{cur[0] + nx, cur[1] + ny}
            p_in_b := [2]f32{cur[0] - nx, cur[1] - ny}
            p_in_a := [2]f32{prev[0] - nx, prev[1] - ny}
            if data.vertex_count + 6 <= data.max_vertices {
                // Two triangles: (a_out, b_out, b_in) + (a_out, b_in, a_in)
                push_vertex(data, {{p_out_a[0], p_out_a[1]}, dummy_uv, color})
                push_vertex(data, {{p_out_b[0], p_out_b[1]}, dummy_uv, color})
                push_vertex(data, {{p_in_b[0], p_in_b[1]}, dummy_uv, color})
                push_vertex(data, {{p_out_a[0], p_out_a[1]}, dummy_uv, color})
                push_vertex(data, {{p_in_b[0], p_in_b[1]}, dummy_uv, color})
                push_vertex(data, {{p_in_a[0], p_in_a[1]}, dummy_uv, color})
            }
            prev = cur
        }
    }
}
