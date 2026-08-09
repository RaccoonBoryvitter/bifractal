package ui

import "core:fmt"

import "../fractal"
import "../palette"
import "../settings"

format_zoom :: proc(zoom: f32) -> string {
    if zoom > 1_000_000 || zoom < 0.000_001 {
        return fmt.tprintf("%e", zoom)
    }
    return fmt.tprintf("%.4f", zoom)
}

format_coord :: proc(v: [2]f32, format: settings.Coord_Format) -> string {
    switch format {
    case .Decimal:
        return fmt.tprintf("%+.6f %+.6fi", v.x, v.y)
    case .Scientific:
        return fmt.tprintf("%+.4e %+.4ei", v.x, v.y)
    case .Fraction:
        return fmt.tprintf("%+.6f %+.6fi", v.x, v.y)
    }
    return ""
}

fractal_kind_name :: proc(f: ^fractal.Fractal) -> string {
    switch f.kind {
    case .Mandelbrot:
        return "Mandelbrot"
    case .Julia:
        return "Julia"
    }
    return "?"
}

fractal_params_name :: proc(f: ^fractal.Fractal) -> string {
    switch f.kind {
    case .Mandelbrot:
        if d, ok := &f.data.(fractal.Mandelbrot_Data); ok {
            return fmt.tprintf("Power: %.2f", d.power)
        }
    case .Julia:
        if d, ok := &f.data.(fractal.Julia_Data); ok {
            return fmt.tprintf(
                "Constant: %+.3f%+.3fi",
                real(d.constant),
                imag(d.constant),
            )
        }
    }
    return ""
}

palette_name :: proc(p: palette.Palette) -> string {
    for preset in palette.PALETTE_PRESETS {
        if preset.offset == p.offset &&
           preset.amplitude == p.amplitude &&
           preset.frequency == p.frequency &&
           preset.phase == p.phase {
            return preset.name
        }
    }
    return "Custom"
}
