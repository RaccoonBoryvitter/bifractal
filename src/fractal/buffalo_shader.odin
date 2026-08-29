package fractal

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        BUFFALO_SHADER_EXT :: "spv"
        BUFFALO_SHADER_ENTRY :: "main"
    } else {
        BUFFALO_SHADER_EXT :: "dxil"
        BUFFALO_SHADER_ENTRY :: "main"
    }
} else when ODIN_OS == .Darwin {
    BUFFALO_SHADER_EXT :: "metal"
    BUFFALO_SHADER_ENTRY :: "main0"
} else {
    BUFFALO_SHADER_EXT :: "spv"
    BUFFALO_SHADER_ENTRY :: "main"
}

BUFFALO_SHADER :: #load(
    "../../assets/shaders/compiled/buffalo." + BUFFALO_SHADER_EXT,
)
