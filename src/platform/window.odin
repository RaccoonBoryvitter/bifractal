package platform

import "core:log"
import sdl "vendor:sdl3"
import "../geom"

WINDOW_TITLE :: "Odin Zoom"
WINDOW_RESOLUTION :: geom.Extent_2D {
	w = 1280,
	h = 720,
}

Window :: struct {
	handle: ^sdl.Window,
	size:   geom.Extent_2D,
}

init_window :: proc() -> ^sdl.Window {
	ok := sdl.Init({.VIDEO, .EVENTS})
	if !ok {
		log.errorf("unable to initialize SDL: %s", sdl.GetError())
		return nil
	}

	main_scale := sdl.GetDisplayContentScale(sdl.GetPrimaryDisplay())
	window := sdl.CreateWindow(
		WINDOW_TITLE,
		i32(f32(WINDOW_RESOLUTION.w) * main_scale),
		i32(f32(WINDOW_RESOLUTION.h) * main_scale),
		{.RESIZABLE, .HIGH_PIXEL_DENSITY},
	)
	if window == nil {
		log.errorf("unable to create SDL window: %s", sdl.GetError())
		sdl.Quit()
		return nil
	}

	sdl.SetWindowPosition(
		window,
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
	)

	return window
}
