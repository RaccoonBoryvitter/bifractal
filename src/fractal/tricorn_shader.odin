package fractal

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        TRICORN_SHADER_EXT :: "spv"
        TRICORN_SHADER_ENTRY :: "main"
    } else {
        TRICORN_SHADER_EXT :: "dxil"
        TRICORN_SHADER_ENTRY :: "main"
    }
} else when ODIN_OS == .Darwin {
    TRICORN_SHADER_EXT :: "metal"
    TRICORN_SHADER_ENTRY :: "main0"
} else {
    TRICORN_SHADER_EXT :: "spv"
    TRICORN_SHADER_ENTRY :: "main"
}

TRICORN_SHADER :: #load(
    "../../assets/shaders/compiled/tricorn." + TRICORN_SHADER_EXT,
)
