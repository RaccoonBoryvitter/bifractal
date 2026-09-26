package render

import "core:c"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

import sdl "vendor:sdl3"

import "../geom"
import "../platform"

SCREENSHOT_DIR_NAME :: "screenshots"

save_output_to_png :: proc(
    gpu: ^platform.Gpu_Context,
    size: geom.Extent_2D,
) -> (
    path: string,
    ok: bool,
) {
    if gpu.output == nil || size.w == 0 || size.h == 0 {
        return "", false
    }

    pixels_f32, read_ok := readback_output(gpu, size)
    if !read_ok {
        return "", false
    }
    defer delete(pixels_f32)

    rgba_bytes := make([dynamic]u8, len(pixels_f32), context.temp_allocator)
    for i in 0 ..< len(pixels_f32) / 4 {
        rgba_bytes[i * 4 + 0] = float_to_u8(pixels_f32[i * 4 + 0])
        rgba_bytes[i * 4 + 1] = float_to_u8(pixels_f32[i * 4 + 1])
        rgba_bytes[i * 4 + 2] = float_to_u8(pixels_f32[i * 4 + 2])
        rgba_bytes[i * 4 + 3] = float_to_u8(pixels_f32[i * 4 + 3])
    }

    full_path, dir_ok := ensure_screenshot_dir()
    if !dir_ok {
        return "", false
    }
    defer delete(full_path)

    filename := make_filename(context.temp_allocator)
    file_path, join_err := filepath.join(
        []string{full_path, filename},
        context.temp_allocator,
    )
    if join_err != nil {
        log.errorf("failed to join screenshot path: %v", join_err)
        return "", false
    }

    surface := sdl.CreateSurfaceFrom(
        c.int(size.w),
        c.int(size.h),
        .ABGR8888,
        raw_data(rgba_bytes),
        c.int(size.w * 4),
    )
    if surface == nil {
        log.errorf("failed to create SDL surface: %s", sdl.GetError())
        return "", false
    }
    defer sdl.DestroySurface(surface)

    cpath, cpath_err := strings.clone_to_cstring(
        file_path,
        context.temp_allocator,
    )
    if cpath_err != nil {
        log.errorf("failed to allocate cstring for path: %v", cpath_err)
        return "", false
    }

    if !sdl.SavePNG(surface, cpath) {
        log.errorf("failed to save PNG: %s", sdl.GetError())
        return "", false
    }

    return strings.clone(file_path), true
}

@(private = "file")
readback_output :: proc(
    gpu: ^platform.Gpu_Context,
    size: geom.Extent_2D,
) -> (
    data: []f32,
    ok: bool,
) {
    bytes_size := u32(size.w * size.h * 4 * size_of(u16))

    transfer_buf := sdl.CreateGPUTransferBuffer(
        gpu.device,
        sdl.GPUTransferBufferCreateInfo{usage = .DOWNLOAD, size = bytes_size},
    )
    if transfer_buf == nil {
        log.errorf("failed to create transfer buffer: %s", sdl.GetError())
        return nil, false
    }
    defer sdl.ReleaseGPUTransferBuffer(gpu.device, transfer_buf)

    cmd := sdl.AcquireGPUCommandBuffer(gpu.device)
    if cmd == nil {
        log.errorf(
            "failed to acquire cmd buffer for readback: %s",
            sdl.GetError(),
        )
        return nil, false
    }

    copy_pass := sdl.BeginGPUCopyPass(cmd)
    sdl.DownloadFromGPUTexture(
        copy_pass,
        sdl.GPUTextureRegion {
            texture = gpu.output,
            mip_level = 0,
            layer = 0,
            x = 0,
            y = 0,
            z = 0,
            w = u32(size.w),
            h = u32(size.h),
            d = 1,
        },
        sdl.GPUTextureTransferInfo{transfer_buffer = transfer_buf, offset = 0},
    )
    sdl.EndGPUCopyPass(copy_pass)

    fence := sdl.SubmitGPUCommandBufferAndAcquireFence(cmd)
    if fence == nil {
        log.errorf("failed to submit readback cmd buffer: %s", sdl.GetError())
        return nil, false
    }
    defer sdl.ReleaseGPUFence(gpu.device, fence)

    if !sdl.WaitForGPUFences(gpu.device, false, &fence, 1) {
        log.errorf("fence wait failed: %s", sdl.GetError())
        return nil, false
    }

    mapped := sdl.MapGPUTransferBuffer(gpu.device, transfer_buf, false)
    if mapped == nil {
        log.errorf("failed to map transfer buffer: %s", sdl.GetError())
        return nil, false
    }
    defer sdl.UnmapGPUTransferBuffer(gpu.device, transfer_buf)

    src := ([^]u16)(mapped)[:size.w * size.h * 4]
    out := make([]f32, len(src))
    for v, i in src {
        out[i] = half_to_float(v)
    }
    return out, true
}

@(private = "file")
half_to_float :: proc(h: u16) -> f32 {
    sign := f32((h >> 15) & 0x1)
    exp := i32((h >> 10) & 0x1F)
    mant := u32(h & 0x3FF)

    f: u32
    switch exp {
    case 0:
        if mant == 0 {
            f = u32(sign) << 31
        }
        else {
            e := i32(-14)
            for (mant & 0x400) == 0 {
                mant <<= 1
                e -= 1
            }
            mant &= 0x3FF
            f = (u32(sign) << 31) | (u32(e + 127) << 23) | (mant << 13)
        }
    case 31:
        f = (u32(sign) << 31) | (0xFF << 23) | (mant << 13)
    case:
        f = (u32(sign) << 31) | (u32(exp - 15 + 127) << 23) | (mant << 13)
    }
    return transmute(f32)f
}

@(private = "file")
float_to_u8 :: proc(v: f32) -> u8 {
    if v <= 0 do return 0
    if v >= 1 do return 255
    return u8(v * 255.0 + 0.5)
}

@(private = "file")
ensure_screenshot_dir :: proc(
    allocator := context.allocator,
) -> (
    string,
    bool,
) {
    base := sdl.GetBasePath()
    if base == nil {
        log.warn("SDL_GetBasePath() returned nil")
        return "", false
    }

    dir, clone_err := strings.clone_from_cstring(base, allocator)
    if clone_err != nil {
        log.errorf("failed to clone screenshots dir: %v", clone_err)
        return "", false
    }
    if dir == "" {
        return "", false
    }

    full, join_err := filepath.join({dir, SCREENSHOT_DIR_NAME}, allocator)
    delete(dir, allocator)
    if join_err != nil {
        log.errorf("failed to join screenshots dir: %v", join_err)
        return "", false
    }

    if mk_err := os.make_directory(full); mk_err != nil {
        if mk_err != .Exist {
            log.errorf("failed to create %s: %v", full, mk_err)
            delete(full, allocator)
            return "", false
        }
    }
    return full, true
}

@(private = "file")
make_filename :: proc(allocator := context.allocator) -> string {
    now := time.now()
    dt, _ := time.time_to_datetime(now)
    return fmt.tprintf(
        "bifractal_%04d-%02d-%02d_%02d-%02d-%02d.png",
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
    )
}
