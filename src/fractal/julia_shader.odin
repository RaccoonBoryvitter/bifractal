package fractal

when ODIN_OS == .Windows {
	when #config(SHADER_BACKEND, "dx12") == "vulkan" {
		JULIA_SHADER_EXT   :: "spv"
		JULIA_SHADER_ENTRY :: "main"
	} else {
		JULIA_SHADER_EXT   :: "dxil"
		JULIA_SHADER_ENTRY :: "main"
	}
} else when ODIN_OS == .Darwin {
	JULIA_SHADER_EXT   :: "metal"
	JULIA_SHADER_ENTRY :: "main0"
} else {
	JULIA_SHADER_EXT   :: "spv"
	JULIA_SHADER_ENTRY :: "main"
}

JULIA_SHADER :: #load("../../assets/shaders/compiled/julia." + JULIA_SHADER_EXT)
