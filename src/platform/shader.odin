package platform

import sdl "vendor:sdl3"

when ODIN_OS == .Windows {
	when #config(SHADER_BACKEND, "dx12") == "vulkan" {
		SHADER_FORMAT :: sdl.GPUShaderFormatFlag.SPIRV
	} else {
		SHADER_FORMAT :: sdl.GPUShaderFormatFlag.DXIL
	}
} else when ODIN_OS == .Darwin {
	SHADER_FORMAT :: sdl.GPUShaderFormatFlag.MSL
} else {
	SHADER_FORMAT :: sdl.GPUShaderFormatFlag.SPIRV
}
