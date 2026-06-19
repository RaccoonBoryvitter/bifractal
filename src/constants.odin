package main

// Window configuration
WINDOW_TITLE :: "Odin Zoom"
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

// Shader paths
MANDELBROT_SHADER_PATH :: "../assets/shaders/compiled/mandelbrot.spv"
UI_VERTEX_SHADER_PATH :: "../assets/shaders/compiled/ui.vert.spv"
UI_FRAGMENT_SHADER_PATH :: "../assets/shaders/compiled/ui.frag.spv"

// UI configuration
MAX_UI_VERTICES :: 65536
UI_CONTROL_WINDOW_WIDTH :: 360
UI_CONTROL_WINDOW_HEIGHT :: 200

// Fractal navigation
FRACTAL_PAN_FACTOR :: 0.05
FRACTAL_ZOOM_SCROLL_FACTOR :: 0.1
FRACTAL_MOUSE_DRAG_SCALE :: 2.0

// Fractal iteration limits
FRACTAL_MIN_ITERATIONS :: 8
FRACTAL_MAX_ITERATIONS :: 1024
FRACTAL_ITERATION_STEP :: 8
FRACTAL_ITERATION_DECREASE_STEP :: 10

// Default fractal parameters
FRACTAL_DEFAULT_ZOOM :: 0.5
FRACTAL_DEFAULT_CENTER_X :: -0.5
FRACTAL_DEFAULT_CENTER_Y :: 0.0
FRACTAL_DEFAULT_MAX_ITER :: 256

// Palette visualization
PALETTE_SWATCH_STEPS :: 64
PALETTE_PRESET_SWATCH_STEPS :: 16
PALETTE_SWATCH_WIDTH :: 64
