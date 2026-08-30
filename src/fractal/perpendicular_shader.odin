package fractal

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        PERPENDICULAR_SHADER_EXT :: "spv"
        PERPENDICULAR_SHADER_ENTRY :: "main"
    } else {
        PERPENDICULAR_SHADER_EXT :: "dxil"
        PERPENDICULAR_SHADER_ENTRY :: "main"
    }
} else when ODIN_OS == .Darwin {
    PERPENDICULAR_SHADER_EXT :: "metal"
    PERPENDICULAR_SHADER_ENTRY :: "main0"
} else {
    PERPENDICULAR_SHADER_EXT :: "spv"
    PERPENDICULAR_SHADER_ENTRY :: "main"
}

PERPENDICULAR_SHADER :: #load(
    "../../assets/shaders/compiled/perpendicular." + PERPENDICULAR_SHADER_EXT,
)
