package game

import "core:fmt"
import mem "core:mem"
import rl "lib/raylib"

MAX_TEXTURE_SIZE :: 4096
TARGET_FPS :: 60
TARGET_TIME_STEP :: 1.0 / cast(f32)TARGET_FPS
WINDOW_WIDTH :: 480
WINDOW_HEIGHT :: 360

init :: proc() {
	loadTextures()
	initSpriteDefs()
	loadShaders()
}

deinit :: proc() {
	unloadTextures()
	unloadShaders()
}

Alloc :: mem.Allocator
globalCamera := rl.Camera2D {
	offset   = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
	target   = {0.0, 0.0},
	rotation = 0.0,
	zoom     = 1.0,
}

globalCamera3D := rl.Camera3D {
	position   = {10.0, 5.0, 10.0},
	target     = {0.0, 0.0, 0.0},
	up         = {0.0, 1.0, 0.0},
	fovy       = 45.0,
	projection = .PERSPECTIVE,
}
debugDrawGlobalCamera3DInfo :: proc(x: i32, y: i32) {
	dy := y
	fontSize: i32 = 16
	debugDrawTextOutline(
		rl.TextFormat("pos: %s", vector3ToStringTemp(globalCamera3D.position)),
		x,
		dy,
		fontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += fontSize
	debugDrawTextOutline(
		rl.TextFormat("target: %s", vector3ToStringTemp(globalCamera3D.target)),
		x,
		dy,
		fontSize,
		rl.WHITE,
		rl.BLACK,
	)
}
globalChunkWorld := ChunkWorld {
	pos       = {-1, -1},
	genCutoff = 0.5,
}
globalGuiCamera := rl.Camera2D {
	offset   = {0.0, 0.0},
	target   = {0.0, 0.0},
	rotation = 0.0,
	zoom     = 1.0,
}


Elevator3D :: struct {
	model:      rl.Model,
	animCount:  i32,
	anim:       [^]rl.ModelAnimation,
	animFrame:  i32,
	animActive: bool,
}
globalElevator3D: Elevator3D
createElevator3D :: proc(modelPath: cstring) -> Elevator3D {
	e: Elevator3D
	e.model = rl.LoadModel(modelPath)
	e.anim = rl.LoadModelAnimations(modelPath, &e.animCount)
	e.animFrame = 0
	e.animActive = false
	return e
}
destroyElevator3D :: proc(e: Elevator3D) {
	rl.UnloadModel(e.model)
	rl.UnloadModelAnimations(e.anim, e.animCount)
}
updateElevator3D :: proc(e: ^Elevator3D) {
	if e.animActive {
		e.animFrame += 1
		for i in 0 ..< e.animCount {
			rl.UpdateModelAnimation(e.model, e.anim[i], 0)
		}
	}
}

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

	regenerateChunkWorld(&globalChunkWorld)

	gameMusic := loadMusicStream(.KowloonSmokeBreak)
	rl.PlayMusicStream(gameMusic)
	gameObjects := make([dynamic]GameObject, context.allocator)
	globalGameObjects = &gameObjects

	// Game init
	globalElevator3D = createElevator3D("mod/elevator.glb")
	defer destroyElevator3D(globalElevator3D)

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
		globalCamera.offset =
			getObjCenterAbs(player.object^) * -1.0 + {WINDOW_WIDTH, WINDOW_HEIGHT} / 2.0
		updateChunkWorld(&globalChunkWorld, player.object^)
		rl.ClearBackground(rl.BLACK)
		rl.BeginDrawing()
		rl.BeginTextureMode(gameRenderTex)
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode2D(globalCamera)
		drawChunkWorld(&globalChunkWorld)
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

		rl.UpdateCamera(&globalCamera3D, .FIRST_PERSON)

		if (rl.IsKeyPressed(.BACKSPACE)) {
			globalElevator3D.animActive = true
		}
		updateElevator3D(&globalElevator3D)

		rl.BeginTextureMode(renderTex3D)
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(globalCamera3D)
		rl.ClearBackground({0.0, 0.0, 0.0, 0.0})
		rl.DrawGrid(10, 1.0)
		rl.DrawModel(globalElevator3D.model, {0.0, 0.0, 0.0}, 1.0, rl.WHITE)
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
