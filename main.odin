package game

import "base:runtime"
import "core:c"
import "core:mem"
import rl "lib/raylib"

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	@(private = "file")
	web_context: runtime.Context

	@(export)
	main_start :: proc "c" () {
		context = runtime.default_context()

		// The WASM allocator doesn't seem to work properly in combination with
		// emscripten. There is some kind of conflict with how the manage memory.
		// So this sets up an allocator that uses emscripten's malloc.
		context.allocator = emscripten_allocator()
		runtime.init_global_temporary_allocator(1 * mem.Megabyte)

		// Since we now use js_wasm32 we should be able to remove this and use
		// context.logger = log.create_console_logger(). However, that one produces
		// extra newlines on web. So it's a bug in that core lib.
		context.logger = create_emscripten_logger()

		web_context = context

		initRaylib()
		init()
	}

	@(export)
	main_update :: proc "c" () -> bool {
		context = web_context

		return true
	}

	@(export)
	main_end :: proc "c" () {
		context = web_context
		deinit()
		deinitRaylib()
	}

	@(export)
	web_window_size_changed :: proc "c" (w: c.int, h: c.int) {
		context = web_context
		// game.parent_window_size_changed(int(w), int(h))
	}
} else {
	main :: proc() {
		initRaylib()
		defer deinitRaylib()
		// TODO: Only ever explicitly pass gameAlloc so that long-term memory allocations are explicit
		// Currently this causes errors, I don't understand how this works apparently
		//context.allocator = mem.panic_allocator()
		init()
		context.allocator = engine.frameAlloc
		context.temp_allocator = engine.frameAlloc
		defer deinit()

		setGameGlobals()

		for !rl.WindowShouldClose() && !global.windowCloseRequest {
			gameStep()
		}

		for i in 0 ..< len(engine.gameObjects) {
			engine.gameObjects[i].destroyProc(engine.gameObjects[i].data)
		}
	}
}
