package ui

import "core:fmt"
import "core:math"

import "../fractal"
import "../palette"
import "../settings"

format_zoom :: proc(zoom: f32) -> string {
    if zoom > 1_000_000 || zoom < 0.000_001 {
        return fmt.tprintf("%e", zoom)
    }
    return fmt.tprintf("%.4f", zoom)
}

FRACTION_MAX_WIDTH :: 30

format_coord :: proc(v: [2]f32, format: settings.Coord_Format) -> string {
    switch format {
    case .Decimal:
        return fmt.tprintf("%+.6f %+.6fi", v.x, v.y)
    case .Scientific:
        return fmt.tprintf("%+.4e %+.4ei", v.x, v.y)
    case .Fraction:
        fraction := fmt.tprintf(
            "%s %si",
            format_fraction(v.x),
            format_fraction(v.y),
        )

        fraction_len := len(fraction)
        if fraction_len > FRACTION_MAX_WIDTH {
            return fraction
        }

        return fmt.tprintf(
            "%s%*s",
            fraction,
            FRACTION_MAX_WIDTH - fraction_len,
            " ",
        )
    }
    return ""
}

@(private = "file")
format_fraction :: proc(v: f32) -> string {
    if math.is_nan(v) || math.is_inf(v) {
        return fmt.tprintf("%g", v)
    }

    if math.abs(v) >= 1.0e6 || (v != 0 && math.abs(v) < 1.0e-4) {
        return fmt.tprintf("%.4e", v)
    }

    num, den, ok := continued_fraction(v)
    if !ok {
        return fmt.tprintf("%.6f", v)
    }

    approx := f32(num) / f32(den)
    if math.abs(v - approx) > 1.0e-5 * max(1.0, math.abs(v)) {
        return fmt.tprintf("%.6f", v)
    }

    if den == 1 {
        return fmt.tprintf("%d", num)
    }
    return fmt.tprintf("%d/%d", num, den)
}

@(private = "file")
continued_fraction :: proc(v: f32) -> (num, den: int, ok: bool) {
    if math.is_nan(v) || math.is_inf(v) {
        return 0, 0, false
    }
    if v == 0 {
        return 0, 1, true
    }

    negative := v < 0
    x := math.abs(v)

    pnum, pden := 0, 1
    num, den = 1, 0

    max_val := 1_000_000
    max_iter := 20

    for _ in 0 ..< max_iter {
        a := int(math.floor(x))
        if f32(a) > x - 1.0e-9 && f32(a) < x + 1.0e-9 {
            x = f32(a)
        }
        x = x - f32(a)

        new_num := a * num + pnum
        new_den := a * den + pden
        if new_den == 0 || new_den > max_val || new_num > max_val {
            break
        }

        pnum, pden = num, den
        num, den = new_num, new_den

        if x < 1.0e-9 {
            break
        }
        x = 1.0 / x
    }

    if negative {
        num = -num
    }
    return num, den, true
}

fractal_kind_name :: proc(f: ^fractal.Fractal) -> string {
    switch f.kind {
    case .Mandelbrot:
        return "Mandelbrot"
    case .Julia:
        return "Julia"
    case .Burning_Ship:
        return "Burning Ship"
    case .Tricorn:
        return "Tricorn"
    case .Celtic:
        return "Celtic"
    case .Buffalo:
        return "Buffalo"
    case .Cross:
        return "Cross"
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
    case .Burning_Ship:
        if d, ok := &f.data.(fractal.Burning_Ship_Data); ok {
            return fmt.tprintf("Power: %.2f", d.power)
        }
    case .Tricorn:
        if d, ok := &f.data.(fractal.Tricorn_Data); ok {
            return fmt.tprintf("Power: %.2f", d.power)
        }
    case .Celtic:
        if d, ok := &f.data.(fractal.Celtic_Data); ok {
            return fmt.tprintf("Power: %.2f", d.power)
        }
    case .Buffalo:
        if d, ok := &f.data.(fractal.Buffalo_Data); ok {
            return fmt.tprintf("Power: %.2f", d.power)
        }
    case .Cross:
        if d, ok := &f.data.(fractal.Cross_Data); ok {
            return fmt.tprintf("Power: %.2f", d.power)
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
