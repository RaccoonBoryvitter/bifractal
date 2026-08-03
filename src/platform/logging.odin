package platform

import "base:runtime"
import "core:fmt"
import "core:log"
import sdl "vendor:sdl3"

sdl_log_callback :: proc "c" (
	userdata: rawptr,
	category: sdl.LogCategory,
	priority: sdl.LogPriority,
	message: cstring,
) {
	context = runtime.default_context()
	logger := (^log.Logger)(userdata)
	if logger == nil || logger.procedure == nil {
		return
	}

	level: log.Level
	switch priority {
	case .INVALID:
		level = .Debug
	case .TRACE, .VERBOSE, .DEBUG:
		level = .Debug
	case .INFO:
		level = .Info
	case .WARN:
		level = .Warning
	case .ERROR:
		level = .Error
	case .CRITICAL:
		level = .Fatal
	}

	formatted := fmt.tprintf("[SDL/%s] %s", sdl_category_name(category), message)
	logger.procedure(logger.data, level, formatted, logger.options)
}

sdl_category_name :: proc(category: sdl.LogCategory) -> string {
	#partial switch category {
	case .APPLICATION: return "APP"
	case .ERROR:       return "ERROR"
	case .ASSERT:      return "ASSERT"
	case .SYSTEM:      return "SYSTEM"
	case .AUDIO:       return "AUDIO"
	case .VIDEO:       return "VIDEO"
	case .RENDER:      return "RENDER"
	case .INPUT:       return "INPUT"
	case .TEST:        return "TEST"
	case .GPU:         return "GPU"
	case .CUSTOM:      return "CUSTOM"
	}
	return "UNKNOWN"
}
