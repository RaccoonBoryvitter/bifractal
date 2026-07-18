package main

// Window configuration
WINDOW_TITLE :: "Odin Zoom"
WINDOW_RESOLUTION :: Extent_2D {
    w = 1280,
    h = 720,
}

// UI configuration
MAX_UI_VERTICES :: 65536
UI_CONTROL_WINDOW_WIDTH :: 360
UI_CONTROL_WINDOW_HEIGHT :: 200

// Fractal navigation
FRACTAL_PAN_FACTOR :: 0.05
FRACTAL_ZOOM_SCROLL_FACTOR :: 0.1
FRACTAL_MOUSE_DRAG_SCALE :: 2.0
FRACTAL_MIN_ZOOM :: 0.1
FRACTAL_MIN_ZOOM_LOG :: -2.3025850929940455

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

PALETTE_PRESETS :: [?]Palette_Preset {
    {
        name = "Electric",
        a = {0.5, 0.5, 0.5, 0.0},
        b = {0.5, 0.5, 0.5, 0.0},
        c = {1.0, 1.0, 1.0, 0.0},
        d = {0.0, 0.10, 0.20, 0.0},
    },
    {
        name = "Fire",
        a = {0.5, 0.2, 0.1, 0.0},
        b = {0.5, 0.4, 0.1, 0.0},
        c = {1.0, 0.7, 0.4, 0.0},
        d = {0.0, 0.15, 0.20, 0.0},
    },
    {
        name = "Ocean",
        a = {0.2, 0.4, 0.6, 0.0},
        b = {0.2, 0.3, 0.4, 0.0},
        c = {1.0, 1.0, 1.0, 0.0},
        d = {0.0, 0.10, 0.25, 0.0},
    },
    {
        name = "Grayscale",
        a = {0.5, 0.5, 0.5, 0.0},
        b = {0.5, 0.5, 0.5, 0.0},
        c = {1.0, 1.0, 1.0, 0.0},
        d = {0.0, 0.0, 0.0, 0.0},
    },
    {
        name = "Candy",
        a = {0.5, 0.5, 0.5, 0.0},
        b = {0.5, 0.5, 0.5, 0.0},
        c = {1.0, 0.7, 0.4, 0.0},
        d = {0.0, 0.15, 0.20, 0.0},
    },
    {
        name = "Sunset",
        a = {0.8, 0.5, 0.4, 0.0},
        b = {0.2, 0.4, 0.2, 0.0},
        c = {2.0, 1.0, 1.0, 0.0},
        d = {0.5, 0.25, 0.25, 0.0},
    },
    {
        name = "Neon",
        a = {0.5, 0.5, 0.5, 0.0},
        b = {0.5, 0.5, 0.5, 0.0},
        c = {0.0, 0.33, 0.67, 0.0},
        d = {0.0, 0.10, 0.20, 0.0},
    },
    {
        name = "Gold",
        a = {0.5, 0.4, 0.1, 0.0},
        b = {0.5, 0.3, 0.1, 0.0},
        c = {1.0, 0.8, 0.3, 0.0},
        d = {0.0, 0.10, 0.10, 0.0},
    },
}

FPS_INTERVAL_MS :: 500
