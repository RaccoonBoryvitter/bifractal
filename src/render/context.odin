package render

import "core:mem"

import sdl "vendor:sdl3"

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
