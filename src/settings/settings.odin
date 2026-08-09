package settings

import "core:encoding/json"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import sdl "vendor:sdl3"

Settings :: struct {
    hud: Hud_Settings,
}

Hud_Settings :: struct {
    enabled:             bool,
    anchor:              Hud_Anchor,
    opacity:             f32,
    padding:             f32,
    show_fps:            bool,
    show_frame_ms:       bool,
    show_fractal_kind:   bool,
    show_fractal_params: bool,
    show_center:         bool,
    show_zoom:           bool,
    show_iter:           bool,
    show_mouse:          bool,
    show_resolution:     bool,
    show_palette:        bool,
    coord_format:        Coord_Format,
    show_background:     bool,
    click_through:       bool,
}

Hud_Anchor :: enum {
    TopRight,
    TopLeft,
    BottomRight,
    BottomLeft,
}

Coord_Format :: enum {
    Decimal,
    Scientific,
    Fraction,
}

SETTINGS_FILE_NAME :: "settings.json"

settings_path :: proc(allocator := context.allocator) -> (string, bool) {
    base := sdl.GetBasePath()
    if base == nil {
        log.warn(
            "SDL_GetBasePath returned nil; settings will not be persisted",
        )
        return "", false
    }

    dir := strings.clone(string(base), allocator)
    sdl.free(rawptr(base))
    if dir == "" {
        log.error("failed to clone base path")
        return "", false
    }

    full, join_err := filepath.join(
        []string{dir, SETTINGS_FILE_NAME},
        allocator,
    )
    delete(dir, allocator)
    if join_err != nil {
        log.errorf("failed to join settings path: %v", join_err)
        return "", false
    }
    return full, true
}

load :: proc(allocator := context.allocator) -> (Settings, bool) {
    defaults := default_settings()
    path, ok := settings_path(allocator)
    if !ok {
        return defaults, false
    }
    defer delete(path, allocator)

    data, read_err := os.read_entire_file_from_path(path, allocator)
    if read_err != nil {
        log.infof(
            "no settings file at %s (%v); using defaults",
            path,
            read_err,
        )
        return defaults, false
    }
    defer delete(data, allocator)

    if err := json.unmarshal(data, &defaults); err != nil {
        log.warnf("failed to parse %s (%v); using defaults", path, err)
        return default_settings(), false
    }

    log.infof("loaded settings from %s", path)
    return defaults, true
}

save :: proc(s: Settings, allocator := context.allocator) -> bool {
    path, ok := settings_path(allocator)
    if !ok {
        return false
    }
    defer delete(path, allocator)

    if dir := filepath.dir(path); dir != "" {
        if err := os.make_directory_all(dir); err != nil {
            log.warnf("could not create %s (%v)", dir, err)
        }
    }

    opt := json.Marshal_Options {
        spec           = .JSON,
        pretty         = true,
        use_spaces     = true,
        spaces         = 4,
        use_enum_names = true,
    }
    data, err := json.marshal(s, opt, allocator)
    if err != nil {
        log.errorf("failed to marshal settings: %v", err)
        return false
    }
    defer delete(data, allocator)

    if write_err := os.write_entire_file_from_bytes(path, data);
       write_err != nil {
        log.errorf("failed to write settings to %s: %v", path, write_err)
        return false
    }
    return true
}
