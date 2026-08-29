package fractal

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        CROSS_SHADER_EXT :: "spv"
        CROSS_SHADER_ENTRY :: "main"
    } else {
        CROSS_SHADER_EXT :: "dxil"
        CROSS_SHADER_ENTRY :: "main"
    }
} else when ODIN_OS == .Darwin {
    CROSS_SHADER_EXT :: "metal"
    CROSS_SHADER_ENTRY :: "main0"
} else {
    CROSS_SHADER_EXT :: "spv"
    CROSS_SHADER_ENTRY :: "main"
}

CROSS_SHADER :: #load(
    "../../assets/shaders/compiled/cross." + CROSS_SHADER_EXT,
)
