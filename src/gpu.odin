package main

import sdl "vendor:sdl3"

GPUResources :: struct {
    device :             ^sdl.GPUDevice,
    compute_pipeline :   ^sdl.GPUComputePipeline,
    texture :            ^sdl.GPUTexture,
    ui_pipeline :        ^sdl.GPUGraphicsPipeline,
    ui_vertex_buffer :   ^sdl.GPUBuffer,
    ui_transfer_buffer : ^sdl.GPUTransferBuffer,
    ui_font_texture :    ^sdl.GPUTexture,
    ui_font_sampler :    ^sdl.GPUSampler,
}
