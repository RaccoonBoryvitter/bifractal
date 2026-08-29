package fractal

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        HEART_SHADER_EXT :: "spv"
        HEART_SHADER_ENTRY :: "main"
    } else {
        HEART_SHADER_EXT :: "dxil"
        HEART_SHADER_ENTRY :: "main"
    }
} else when ODIN_OS == .Darwin {
    HEART_SHADER_EXT :: "metal"
    HEART_SHADER_ENTRY :: "main0"
} else {
    HEART_SHADER_EXT :: "spv"
    HEART_SHADER_ENTRY :: "main"
}

HEART_SHADER :: #load(
    "../../assets/shaders/compiled/heart." + HEART_SHADER_EXT,
)
