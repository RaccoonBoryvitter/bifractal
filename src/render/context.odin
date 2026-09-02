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
    backing: [4096]byte,
    scratch: mem.Arena,
    cmd:     ^sdl.GPUCommandBuffer,
    pass:    Frame_Pass,
}
