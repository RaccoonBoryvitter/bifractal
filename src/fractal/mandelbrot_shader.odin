package fractal

when ODIN_OS == .Windows {
	when #config(SHADER_BACKEND, "dx12") == "vulkan" {
		MANDELBROT_SHADER_EXT   :: "spv"
		MANDELBROT_SHADER_ENTRY :: "main"
	} else {
		MANDELBROT_SHADER_EXT   :: "dxil"
		MANDELBROT_SHADER_ENTRY :: "main"
	}
} else when ODIN_OS == .Darwin {
	MANDELBROT_SHADER_EXT   :: "metal"
	MANDELBROT_SHADER_ENTRY :: "main0"
} else {
	MANDELBROT_SHADER_EXT   :: "spv"
	MANDELBROT_SHADER_ENTRY :: "main"
}

MANDELBROT_SHADER :: #load("../../assets/shaders/compiled/mandelbrot." + MANDELBROT_SHADER_EXT)
