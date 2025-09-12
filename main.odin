package game

import "core:fmt"
import "core:math"
import mem "core:mem"
import rl "lib/raylib"

init :: proc() {
	loadModels()
	loadTextures()
	initSpriteDefs()
	loadShaders()

}

deinit :: proc() {
	unloadModels()
	unloadTextures()
	unloadShaders()
}

Alloc :: mem.Allocator
debugDrawGlobalCamera3DInfo :: proc(x: i32, y: i32) {
	dy := y
	fontSize: i32 = 16
	debugDrawTextOutline(
		rl.TextFormat("pos: %s", vector3ToStringTemp(global.camera3D.position)),
		x,
		dy,
		fontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += fontSize
	debugDrawTextOutline(
		rl.TextFormat("target: %s", vector3ToStringTemp(global.camera3D.target)),
		x,
		dy,
		fontSize,
		rl.WHITE,
		rl.BLACK,
	)
}
Global :: struct {
	chunkWorld: ChunkWorld,
	elevator3D: Elevator3D,
	camera:     rl.Camera2D,
	camera3D:   rl.Camera3D,
}
global := Global {
	chunkWorld = {pos = {-1, -1}, genCutoff = 0.5},
	camera = {
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		target = {0.0, 0.0},
		rotation = 0.0,
		zoom = 1.0,
	},
	camera3D = {
		position = {0.0, 2.0, 0.0},
		target = {1.0, 2.0, 0.0},
		up = {0.0, 1.0, 0.0},
		fovy = 90.0,
		projection = .PERSPECTIVE,
	},
}

MAX_TEXTURE_SIZE :: 4096
TARGET_FPS :: 60
TARGET_TIME_STEP :: 1.0 / cast(f32)TARGET_FPS
WINDOW_WIDTH :: 480
WINDOW_HEIGHT :: 360

main :: proc() {
	// Raylib init
	rl.SetConfigFlags({.WINDOW_RESIZABLE}) // TODO: Remove artifacts from main framebuffer when resizing
	rl.SetTraceLogLevel(.WARNING)
	rl.SetTargetFPS(TARGET_FPS)
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Elevator Game")
	defer rl.CloseWindow()
	rl.DisableCursor()

	// Engine init
	gameArena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&gameArena)
	defer mem.dynamic_arena_free_all(&gameArena)
	gameAlloc := mem.dynamic_arena_allocator(&gameArena)
	context.allocator = gameAlloc
	// TODO: Only ever explicitly pass gameAlloc so that long-term memory allocations are explicit
	// Currently this causes errors, I don't understand how this works apparently
	//context.allocator = mem.panic_allocator()

	frameArena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&frameArena)
	defer mem.dynamic_arena_free_all(&frameArena)
	context.temp_allocator = mem.dynamic_arena_allocator(&frameArena)

	init()
	defer deinit()
	gameRenderTex := rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	defer rl.UnloadRenderTexture(gameRenderTex)
	renderTex3D := rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	defer rl.UnloadRenderTexture(renderTex3D)

	regenerateChunkWorld(&global.chunkWorld)

	gameMusic := loadMusicStream(.KowloonSmokeBreak)
	rl.PlayMusicStream(gameMusic)
	gameObjects := make([dynamic]GameObject, context.allocator)
	globalGameObjects = &gameObjects

	// Game init
	global.elevator3D = createElevator3D(
		getModel(.Elevator),
		getModel(.ElevatorSlidingDoorLeft),
		getModel(.ElevatorSlidingDoorRight),
	)

	elevator := createElevator(context.allocator, {160.0, 202.0})
	player := createPlayer(context.allocator, {64.0, 64.0})
	_ = createStarBg(context.allocator)

	mem.dynamic_arena_reset(&frameArena)

	for object in globalGameObjects {
		object.startProc(object.data)
	}
	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(gameMusic)
		if rl.IsMouseButtonPressed(.LEFT) {
			player.object.pos = rl.GetMousePosition()
		}
		global.camera.offset =
			getObjCenterAbs(player.object^) * -1.0 + {WINDOW_WIDTH, WINDOW_HEIGHT} / 2.0
		updateChunkWorld(&global.chunkWorld, player.object^)
		rl.ClearBackground(rl.BLACK)
		rl.BeginDrawing()
		rl.BeginTextureMode(gameRenderTex)
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode2D(global.camera)
		drawChunkWorld(&global.chunkWorld)
		for object in globalGameObjects {
			object.updateProc(object.data)
		}
		for object in globalGameObjects {
			object.drawProc(object.data)
		}
		for object in globalGameObjects {
			object.drawEndProc(object.data)
		}
		rl.EndMode2D()
		rl.EndTextureMode()
		drawRenderTexToScreenBuffer(gameRenderTex)

		// rl.UpdateCamera(&global.camera3D, .FIRST_PERSON)

		if rl.IsKeyPressed(.BACKSPACE) {
			enterElevator3D(&global.elevator3D)
		}
		updateElevator3D(&global.elevator3D)

		rl.BeginTextureMode(renderTex3D)
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(global.camera3D)
		rl.ClearBackground({0.0, 0.0, 0.0, 0.0})
		rl.DrawGrid(10, 1.0)
		drawElevator3D(&global.elevator3D)
		rl.EndMode3D()
		rl.EndTextureMode()
		drawRenderTexToScreenBuffer(renderTex3D)
		debugDrawGlobalCamera3DInfo(4, 4)
		rl.EndDrawing()
		mem.dynamic_arena_reset(&frameArena)
	}
	for object in globalGameObjects {
		object.destroyProc(object.data)
	}
}
