#+feature dynamic-literals
package main

import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import "core:math"

import sdl "vendor:sdl3"
import mu  "vendor:microui"

create_font_texture :: proc(device: ^sdl.GPUDevice) -> ^sdl.GPUTexture {
    atlas_size := mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT

    rgba := make([]u8, atlas_size * 4)
    defer delete(rgba)

    for i in 0..<atlas_size {
        v := mu.default_atlas_alpha[i]
        rgba[i*4 + 0] = 255
        rgba[i*4 + 1] = 255
        rgba[i*4 + 2] = 255
        rgba[i*4 + 3] = v
    }

    texture := sdl.CreateGPUTexture(device, sdl.GPUTextureCreateInfo{
        type = .D2,
        format = .R8G8B8A8_UNORM,
        width = mu.DEFAULT_ATLAS_WIDTH,
        height = mu.DEFAULT_ATLAS_HEIGHT,
        layer_count_or_depth = 1,
        num_levels = 1,
        usage = {.SAMPLER}
    })

    transfer_buffer := sdl.CreateGPUTransferBuffer(device, sdl.GPUTransferBufferCreateInfo{
        size = u32(atlas_size * 4),
        usage = .UPLOAD
    })
    ptr := sdl.MapGPUTransferBuffer(device, transfer_buffer, false)
    sdl.memcpy(ptr, raw_data(rgba), uint(atlas_size * 4))
    sdl.UnmapGPUTransferBuffer(device, transfer_buffer)

    command_buffer := sdl.AcquireGPUCommandBuffer(device)
    copy_pass := sdl.BeginGPUCopyPass(command_buffer)
    sdl.UploadToGPUTexture(
        copy_pass,
        sdl.GPUTextureTransferInfo{
            transfer_buffer = transfer_buffer,
            offset = 0,
        },
        sdl.GPUTextureRegion{
            texture = texture,
            w = mu.DEFAULT_ATLAS_WIDTH,
            h = mu.DEFAULT_ATLAS_HEIGHT,
            d = 1,
        },
        false
    )
    sdl.EndGPUCopyPass(copy_pass)
    ok := sdl.SubmitGPUCommandBuffer(command_buffer)
    if !ok {

    }
    sdl.ReleaseGPUTransferBuffer(device, transfer_buffer)

    return texture
}

KEY_MAP := map[sdl.Keycode]mu.Key{
	sdl.K_LSHIFT    = .SHIFT,
	sdl.K_RSHIFT    = .SHIFT,
	sdl.K_LCTRL     = .CTRL,
	sdl.K_RCTRL     = .CTRL,
	sdl.K_LGUI      = .CTRL,
	sdl.K_RGUI      = .CTRL,
	sdl.K_LALT      = .ALT,
	sdl.K_RALT      = .ALT,
	sdl.K_BACKSPACE = .BACKSPACE,
	sdl.K_DELETE    = .DELETE,
	sdl.K_RETURN    = .RETURN,
	sdl.K_LEFT      = .LEFT,
	sdl.K_RIGHT     = .RIGHT,
	sdl.K_HOME      = .HOME,
	sdl.K_END       = .END,
	sdl.K_A         = .A,
	sdl.K_X         = .X,
	sdl.K_C         = .C,
	sdl.K_V         = .V,
}

push_rect :: proc(
    vertices: ^[]UIVertex,
    count: ^int,
    rect, uv: mu.Rect,
    color: mu.Color
)
{
    c := [4]f32{ f32(color.r)/255, f32(color.g)/255, f32(color.b)/255, f32(color.a)/255 }
    x0, y0 := f32(rect.x), f32(rect.y)
    x1, y1 := f32(rect.x + rect.w), f32(rect.y + rect.h)

    white := mu.default_atlas[mu.DEFAULT_ATLAS_WHITE]
    u0 := (f32(white.x) + 0.5) / f32(mu.DEFAULT_ATLAS_WIDTH)
    v0 := (f32(white.y) + 0.5) / f32(mu.DEFAULT_ATLAS_HEIGHT)

    vertices^[count^ + 0] = { {x0, y0}, {u0, v0}, c }
    vertices^[count^ + 1] = { {x1, y0}, {u0, v0}, c }
    vertices^[count^ + 2] = { {x1, y1}, {u0, v0}, c }
    vertices^[count^ + 3] = { {x0, y0}, {u0, v0}, c }
    vertices^[count^ + 4] = { {x1, y1}, {u0, v0}, c }
    vertices^[count^ + 5] = { {x0, y1}, {u0, v0}, c }
    count^ += 6
}

push_rect_uv :: proc(
    vertices: ^[]UIVertex,
    count: ^int,
    rect, src: mu.Rect,
    color: mu.Color,
) {
    c  := [4]f32{ f32(color.r)/255, f32(color.g)/255, f32(color.b)/255, f32(color.a)/255 }
    x0, y0 := f32(rect.x), f32(rect.y)
    x1, y1 := f32(rect.x + rect.w), f32(rect.y + rect.h)

    u0 := f32(src.x) / mu.DEFAULT_ATLAS_WIDTH
    v0 := f32(src.y) / mu.DEFAULT_ATLAS_HEIGHT
    u1 := f32(src.x + src.w) / mu.DEFAULT_ATLAS_WIDTH
    v1 := f32(src.y + src.h) / mu.DEFAULT_ATLAS_HEIGHT

    vertices^[count^ + 0] = { {x0, y0}, {u0, v0}, c }
    vertices^[count^ + 1] = { {x1, y0}, {u1, v0}, c }
    vertices^[count^ + 2] = { {x1, y1}, {u1, v1}, c }
    vertices^[count^ + 3] = { {x0, y0}, {u0, v0}, c }
    vertices^[count^ + 4] = { {x1, y1}, {u1, v1}, c }
    vertices^[count^ + 5] = { {x0, y1}, {u0, v1}, c }
    count^ += 6
}

on_microui_text_input :: proc(event: ^sdl.Event, state: ^AppState) {
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

screen_to_complex :: proc(
    screen_x, screen_y: f32,
    window_width, window_height: u32,
    center: [2]f32,
    zoom: f32
) -> complex64 {
    w := f32(window_width)
    h := f32(window_height)
    return complex(
        (screen_x - w * 0.5) / (h * zoom) + center.x,
        (screen_y - h * 0.5) / (h * zoom) + center.y
    )
}

cosine_palette_cpu :: proc(t: f32, a, b, c, d: [3]f32) -> [3]f32 {
    color := [3]f32{
        a.r + b.r * math.cos(2 * math.PI * (c.r * t + d.r)),
        a.g + b.g * math.cos(2 * math.PI * (c.g * t + d.g)),
        a.b + b.b * math.cos(2 * math.PI * (c.b * t + d.b)),
    }
    return {
        math.clamp(color.r, 0, 1),
        math.clamp(color.g, 0, 1),
        math.clamp(color.b, 0, 1),
    }
}

palette_row :: proc(ui: ^mu.Context, label: string, color: ^[3]f32) {
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
