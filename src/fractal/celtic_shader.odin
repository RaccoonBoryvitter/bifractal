package fractal

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        CELTIC_SHADER_EXT :: "spv"
        CELTIC_SHADER_ENTRY :: "main"
    } else {
        CELTIC_SHADER_EXT :: "dxil"
        CELTIC_SHADER_ENTRY :: "main"
    }
} else when ODIN_OS == .Darwin {
    CELTIC_SHADER_EXT :: "metal"
    CELTIC_SHADER_ENTRY :: "main0"
} else {
    CELTIC_SHADER_EXT :: "spv"
    CELTIC_SHADER_ENTRY :: "main"
}

CELTIC_SHADER :: #load(
    "../../assets/shaders/compiled/celtic." + CELTIC_SHADER_EXT,
)
