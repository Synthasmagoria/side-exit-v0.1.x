package game

import libc "core:c/libc"
import "core:fmt"
import "core:math"
import mem "core:mem"
import rl "lib/raylib"

raylibFree :: libc.free
raylibMalloc :: libc.malloc
raylibCalloc :: libc.calloc
raylibRealloc :: libc.realloc

Alloc :: mem.Allocator

init :: proc() {
	loadModels()
	loadTextures()
	loadShaders()
	loadSounds()
	initSpriteDefs()
	initLights()
	global.defaultMaterial3D = loadPassthroughMaterial3D()
}

deinit :: proc() {
	unloadModels()
	unloadTextures()
	unloadShaders()
	unloadSounds()
	unloadMaterialMapOnly(global.defaultMaterial3D)
}

initLights :: proc() {
	global.lights3D[0] = Light3D {
		enabled  = 1,
		type     = .Point,
		position = {0.0, 3.0, 0.0},
		target   = {0.0, 0.0, 0.0},
		color    = {1.0, 1.0, 1.0, 1.0},
	}
	global.lights3D[1] = Light3D {
		enabled  = 0,
		type     = .Point,
		position = {0.0, 0.0, 0.0},
		target   = {0.0, 0.0, 0.0},
		color    = {1.0, 1.0, 1.0, 1.0},
	}
	global.lights3D[2] = Light3D {
		enabled  = 0,
		type     = .Point,
		position = {0.0, 0.0, 0.0},
		target   = {0.0, 0.0, 0.0},
		color    = {1.0, 1.0, 1.0, 1.0},
	}
	global.lights3D[3] = Light3D {
		enabled  = 0,
		type     = .Point,
		position = {0.0, 0.0, 0.0},
		target   = {0.0, 0.0, 0.0},
		color    = {1.0, 1.0, 1.0, 1.0},
	}
}

debugDrawGlobalCamera3DInfo :: proc(cam: rl.Camera3D, x: i32, y: i32) {
	dy := y
	fontSize: i32 = 16
	debugDrawTextOutline(
		rl.TextFormat("pos: %s", vector3ToStringTemp(cam.position)),
		x,
		dy,
		fontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += fontSize
	debugDrawTextOutline(
		rl.TextFormat("target: %s", vector3ToStringTemp(cam.target)),
		x,
		dy,
		fontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += fontSize
	debugDrawTextOutline(
		rl.TextFormat("look: %s", vector3ToStringTemp(cam.target - cam.position)),
		x,
		dy,
		fontSize,
		rl.WHITE,
		rl.BLACK,
	)
}
Global :: struct {
	ambientLightingColor: rl.Vector4,
	chunkWorld:           ChunkWorld,
	elevator3D:           Elevator3D,
	camera:               rl.Camera2D,
	camera3D:             rl.Camera3D,
	lights3D:             [MAX_LIGHTS]Light3D,
	defaultMaterial3D:    rl.Material,
	debugCamera3D:        rl.Camera3D,
	debugMode:            bool,
}
global := Global {
	ambientLightingColor = {0.1, 0.1, 0.12, 1.0},
	chunkWorld = {pos = {-1, -1}, genCutoff = 0.5},
	camera = {
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		target = {0.0, 0.0},
		rotation = 0.0,
		zoom = 1.0,
	},
	camera3D = {
		position = {0.0, 0.0, 0.0},
		target = {1.0, 0.0, 0.0},
		up = {0.0, 1.0, 0.0},
		fovy = 90.0,
		projection = .PERSPECTIVE,
	},
	debugCamera3D = {
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
	global.elevator3D = createElevator3D()
	player3D := createPlayer3D()

	elevator := createElevator(context.allocator, {160.0, 202.0})
	player := createPlayer(context.allocator, {64.0, 64.0})
	_ = createStarBg(context.allocator)

	mem.dynamic_arena_reset(&frameArena)

	for object in globalGameObjects {
		object.startProc(object.data)
	}
	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(gameMusic)
		if rl.IsKeyPressed(.BACKSPACE) {
			global.debugMode = global.debugMode ? false : true
		}
		currentCamera3D := &global.camera3D
		if global.debugMode {
			rl.UpdateCamera(&global.debugCamera3D, .FIRST_PERSON)
			if rl.IsKeyDown(.SPACE) {
				rl.CameraMoveUp(&global.debugCamera3D, 5.4 * TARGET_TIME_STEP)
			} else if rl.IsKeyDown(.LEFT_SHIFT) {
				rl.CameraMoveUp(&global.debugCamera3D, -5.4 * TARGET_TIME_STEP)
			}
			rl.DisableCursor()
			currentCamera3D = &global.debugCamera3D
		}
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

		if player3D.state == .Inactive && rl.IsKeyPressed(.ONE) {
			movePlayer3D(&player3D, global.camera3D.position, PLAYER_3D_INSIDE_POSITION, .Looking)
		}
		updatePlayer3D(&player3D)

		rl.BeginTextureMode(renderTex3D)
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(currentCamera3D^)
		rl.ClearBackground({0.0, 0.0, 0.0, 0.0})
		rl.DrawGrid(10, 1.0)
		drawElevator3D(&global.elevator3D)
		rl.EndMode3D()
		rl.EndTextureMode()
		drawRenderTexToScreenBuffer(renderTex3D)
		debugDrawGlobalCamera3DInfo(currentCamera3D^, 4, 4)
		rl.EndDrawing()
		mem.dynamic_arena_reset(&frameArena)
	}
	for object in globalGameObjects {
		object.destroyProc(object.data)
	}
}
