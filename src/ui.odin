#+feature dynamic-literals
package main

import intr "base:intrinsics"

import "core:fmt"

import sdl "vendor:sdl3"
import mu  "vendor:microui"

@(private="file")
RGBA8 :: distinct [4]u8

UIVertex :: struct {
    position: [2]f32,
    uv: [2]f32,
    color: [4]f32,
}

UIGlobals :: struct {
    screen_size: [2]f32,
}

create_font_texture :: proc(device: ^sdl.GPUDevice) -> ^sdl.GPUTexture {
    atlas_size := len(mu.default_atlas_alpha)
    atlas_byte_size := atlas_size * size_of(RGBA8)

    raw_atlas := make([]RGBA8, atlas_size)
    defer delete(raw_atlas)

    for alpha, index in mu.default_atlas_alpha {
        raw_atlas[index] = {255, 255, 255, alpha}
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
        size = u32(atlas_byte_size),
        usage = .UPLOAD
    })
    defer sdl.ReleaseGPUTransferBuffer(device, transfer_buffer)

    raw_transfer_buffer := sdl.MapGPUTransferBuffer(device, transfer_buffer, false)
    intr.mem_copy_non_overlapping(
        raw_transfer_buffer, 
        raw_data(raw_atlas),
        atlas_byte_size
    )
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
        // TODO: replace it with logger from AppState later
        fmt.panicf("unable to submit GPU command buffer: %s", sdl.GetError())
    }

    return texture
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
