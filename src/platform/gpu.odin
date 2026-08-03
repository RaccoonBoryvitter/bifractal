package platform

import "core:log"
import sdl "vendor:sdl3"
import "../geom"

Gpu_Context :: struct {
	device:      ^sdl.GPUDevice,
	pipeline:    ^sdl.GPUComputePipeline,
	output:      ^sdl.GPUTexture,
	output_size: geom.Extent_2D,
	name:        string,
	driver:      string,
	valid:       bool,
}

init_gpu :: proc(window: ^sdl.Window) -> ^sdl.GPUDevice {
	gpu_device := sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, true, nil)
	if gpu_device == nil {
		log.errorf("unable to create SDL GPU device: %s", sdl.GetError())
		return nil
	}

	ok := sdl.ClaimWindowForGPUDevice(gpu_device, window)
	if !ok {
		log.errorf("unable to claim window for GPU device: %s", sdl.GetError())
		sdl.DestroyGPUDevice(gpu_device)
		return nil
	}

	ok = sdl.SetGPUSwapchainParameters(gpu_device, window, .SDR, .VSYNC)
	if !ok {
		log.warnf("unable to set swapchain parameters: %s", sdl.GetError())
	}

	ok = sdl.SetGPUAllowedFramesInFlight(gpu_device, 2)
	if !ok {
		log.warnf("unable to set frames in flight: %s", sdl.GetError())
	}

	return gpu_device
}

create_compute_pipeline :: proc(
	device: ^sdl.GPUDevice,
	shader_code: []byte,
	shader_entry: cstring,
	shader_format: sdl.GPUShaderFormatFlag,
) -> ^sdl.GPUComputePipeline {
	compute_pipeline := sdl.CreateGPUComputePipeline(
		device,
		sdl.GPUComputePipelineCreateInfo {
			code = raw_data(shader_code),
			code_size = len(shader_code),
			entrypoint = shader_entry,
			format = {shader_format},
			num_uniform_buffers = 1,
			num_readwrite_storage_textures = 1,
			threadcount_x = 8,
			threadcount_y = 8,
			threadcount_z = 1,
		},
	)

	if compute_pipeline == nil {
		log.errorf("failed to create compute pipeline: %s", sdl.GetError())
	}

	return compute_pipeline
}

resize_gpu_output :: proc(
	ctx: ^Gpu_Context,
	new_size: geom.Extent_2D,
) -> ^sdl.GPUTexture {
	if ctx.output != nil && ctx.device != nil {
		sdl.ReleaseGPUTexture(ctx.device, ctx.output)
	}

	new_output := create_output_texture(ctx.device, new_size)
	if new_output == nil {
		ctx.output = nil
		ctx.output_size = {}
		ctx.valid = false
		return nil
	}

	ctx.output = new_output
	ctx.output_size = new_size
	ctx.valid = true
	return new_output
}

create_output_texture :: proc(
	device: ^sdl.GPUDevice,
	resolution: geom.Extent_2D,
) -> ^sdl.GPUTexture {
	return sdl.CreateGPUTexture(
		device,
		sdl.GPUTextureCreateInfo {
			type                = .D2,
			format              = .R32G32B32A32_FLOAT,
			width               = resolution.w,
			height              = resolution.h,
			layer_count_or_depth = 1,
			num_levels          = 1,
			usage               = {.COMPUTE_STORAGE_WRITE, .SAMPLER, .COMPUTE_STORAGE_READ},
		},
	)
}
