package fractal

when ODIN_OS == .Windows {
    when #config(SHADER_BACKEND, "dx12") == "vulkan" {
        BURNING_SHIP_SHADER_EXT :: "spv"
        BURNING_SHIP_SHADER_ENTRY :: "main"
    } else {
        BURNING_SHIP_SHADER_EXT :: "dxil"
        BURNING_SHIP_SHADER_ENTRY :: "main"
    }
} else when ODIN_OS == .Darwin {
    BURNING_SHIP_SHADER_EXT :: "metal"
    BURNING_SHIP_SHADER_ENTRY :: "main0"
} else {
    BURNING_SHIP_SHADER_EXT :: "spv"
    BURNING_SHIP_SHADER_ENTRY :: "main"
}

BURNING_SHIP_SHADER :: #load(
    "../../assets/shaders/compiled/burning_ship." + BURNING_SHIP_SHADER_EXT,
)
