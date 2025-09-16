package game

import libc "core:c/libc"
import "core:fmt"
import "core:math"
import "core:math/noise"
import mem "core:mem"
import rl "lib/raylib"

raylibFree :: libc.free
raylibMalloc :: libc.malloc
raylibCalloc :: libc.calloc
raylibRealloc :: libc.realloc

Alloc :: mem.Allocator

init :: proc() {
	initMemory()
	loadModels()
	loadTextures()
	loadShaders()
	loadSounds()
	initSpriteDefs()
	initLights()
	initLoadLevelProcs()
	global.gameRenderTexture = rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	global.defaultMaterial3D = loadPassthroughMaterial3D()
	global.renderTextureStack = make([dynamic]rl.RenderTexture, 0, 5, global.gameAlloc)
	global.gameObjects = make([dynamic]GameObject, 0, 100, global.gameAlloc)
	global.gameObjectIdCounter = min(i32)
	global.levelIndex = .Hub
	global.changeLevel = true
}

deinit :: proc() {
	unloadModels()
	unloadTextures()
	unloadShaders()
	unloadSounds()
	unloadMaterialMapOnly(global.defaultMaterial3D)
	deinitMemory()
}

initMemory :: proc() {
	mem.dynamic_arena_init(&global.gameArena)
	defer mem.dynamic_arena_free_all(&global.gameArena)
	global.gameAlloc = mem.dynamic_arena_allocator(&global.gameArena)

	mem.dynamic_arena_init(&global.levelArena)
	defer mem.dynamic_arena_free_all(&global.levelArena)
	global.levelAlloc = mem.dynamic_arena_allocator(&global.levelArena)

	mem.dynamic_arena_init(&global.frameArena)
	defer mem.dynamic_arena_free_all(&global.frameArena)
	global.frameAlloc = mem.dynamic_arena_allocator(&global.frameArena)
}

deinitMemory :: proc() {
	mem.dynamic_arena_destroy(&global.gameArena)
	mem.dynamic_arena_destroy(&global.levelArena)
	mem.dynamic_arena_destroy(&global.frameArena)
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

Level :: enum {
	Hub,
	UnrulyLand,
	_Count,
}
loadLevelProcs: [Level._Count]proc(_: Alloc)
initLoadLevelProcs :: proc() {
	loadLevelProcs[Level.Hub] = loadLevel_Hub
	loadLevelProcs[Level.UnrulyLand] = loadLevel_UnrulyLand
}
loadLevelGeneral :: proc(levelAlloc: Alloc) {
	global.elevator = createElevator(levelAlloc)
	global.elevator.object.pos = {0.0, 56.0}
	global.player = createPlayer(levelAlloc)
}
loadLevel_Hub :: proc(levelAlloc: Alloc) {
	global.cameraFollowPlayer = false
	global.camera.target = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	global.camera.offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	loadLevelGeneral(levelAlloc)
	_ = createHubGraphics(levelAlloc)
	global.player.object.pos = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	global.elevator.object.pos = {146.0, 181.0}
	global.elevator.visible = false
	global.elevator.instant = true

	append(&global.collisionRectangles, iRectangle{47, 0, 10, 237})
	append(&global.collisionRectangles, iRectangle{47, 237, 382, 11})
	append(&global.collisionRectangles, iRectangle{419, 0, 8, 236})
}
loadLevel_UnrulyLand :: proc(levelAlloc: Alloc) {
	global.cameraFollowPlayer = true
	loadLevelGeneral(levelAlloc)
	generateWorld({-64, -64, 128, 128}, 0.5, 4, 8.0)
	global.elevator.visible = false
	global.elevator.instant = true
	_ = createStarBackground(levelAlloc)
}

GENERATION_BLOCK_SIZE :: 16
generateWorld :: proc(area: iRectangle, threshold: f32, seed: i64, frequency: f64) {
	clear(&global.collisionRectangles)
	blocks := make([dynamic]byte, area.width * area.height, area.width * area.height)
	areaWidth := f64(area.width)
	areaHeight := f64(area.height)
	for x in 0 ..< area.width {
		for y in 0 ..< area.height {
			samplePosition := [2]f64 {
				f64(x) / areaWidth * frequency,
				f64(y) / areaHeight * frequency,
			}
			noiseValue := math.step(threshold, noise.noise_2d(seed, samplePosition))
			blocks[x + y * area.width] = cast(byte)noiseValue
		}
	}
	blockStartPosition: iVector2
	wasPreviousBlockSolid: bool
	for y in 0 ..< area.height {
		for x in 0 ..< area.width {
			isBlockSolid := blocks[x + y * area.height] == 1
			if !wasPreviousBlockSolid && isBlockSolid {
				blockStartPosition = {x, y}
			} else if wasPreviousBlockSolid && !isBlockSolid {
				collisionRectangle := iRectangle {
					(blockStartPosition.x + area.x) * GENERATION_BLOCK_SIZE,
					(blockStartPosition.y + area.y) * GENERATION_BLOCK_SIZE,
					(x - blockStartPosition.x + 1) * GENERATION_BLOCK_SIZE,
					GENERATION_BLOCK_SIZE,
				}
				append(&global.collisionRectangles, collisionRectangle)
			}
			if isBlockSolid && x + 1 == area.width {
				collisionRectangle := iRectangle {
					(blockStartPosition.x + area.x) * GENERATION_BLOCK_SIZE,
					(blockStartPosition.y + area.y) * GENERATION_BLOCK_SIZE,
					(x - blockStartPosition.x + 1) * GENERATION_BLOCK_SIZE,
					GENERATION_BLOCK_SIZE,
				}
				append(&global.collisionRectangles, collisionRectangle)
			}
			wasPreviousBlockSolid = isBlockSolid
		}
	}
}
doSolidCollision :: proc(hitbox: rl.Rectangle) -> Maybe(iRectangle) {
	hitboxI32 := iRectangle{i32(hitbox.x), i32(hitbox.y), i32(hitbox.width), i32(hitbox.height)}
	for rectangle in global.collisionRectangles {
		if rectangleInRectangle(hitboxI32, rectangle) {
			return rectangle
		}
	}
	return nil
}
drawSolids :: proc() {
	for rectangle in global.collisionRectangles {
		rectangleF32 := rl.Rectangle {
			f32(rectangle.x),
			f32(rectangle.y),
			f32(rectangle.width),
			f32(rectangle.height),
		}
		rl.DrawRectangleRec(rectangleF32, rl.WHITE)
	}
}

Global :: struct {
	levelIndex:           Level,
	changeLevel:          bool,
	ambientLightingColor: rl.Vector4,
	elevator:             ^Elevator,
	elevator3D:           Elevator3D,
	camera:               rl.Camera2D,
	cameraFollowPlayer:   bool,
	camera3D:             rl.Camera3D,
	player:               ^Player,
	player3D:             Player3D,
	lights3D:             [MAX_LIGHTS]Light3D,
	collisionRectangles:  [dynamic]iRectangle,
	defaultMaterial3D:    rl.Material,
	debugCamera:          rl.Camera2D,
	debugCamera3D:        rl.Camera3D,
	debugMode:            bool,
	currentRenderTexture: Maybe(rl.RenderTexture),
	renderTextureStack:   [dynamic]rl.RenderTexture,
	gameObjects:          [dynamic]GameObject,
	gameObjectIdCounter:  i32,
	frameArena:           mem.Dynamic_Arena,
	frameAlloc:           Alloc,
	levelArena:           mem.Dynamic_Arena,
	levelAlloc:           Alloc,
	gameArena:            mem.Dynamic_Arena,
	gameAlloc:            Alloc,
	gameRenderTexture:    rl.RenderTexture,
	music:                rl.Music,
}
global := Global {
	ambientLightingColor = {0.1, 0.1, 0.12, 1.0},
	collisionRectangles = nil,
	camera = {
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		target = {0.0, 0.0},
		rotation = 0.0,
		zoom = 1.0,
	},
	debugCamera = {
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

/*
    TODO:
    Starting/ending texture mode while in mode 2d/3d sets some state that makes stuff disappear
    For this to work normally 2d/3d mode needs to be begin/end as well
*/
beginNestedTextureMode :: proc(renderTexture: rl.RenderTexture) {
	if global.currentRenderTexture == nil {
		global.currentRenderTexture = renderTexture
		rl.BeginTextureMode(global.currentRenderTexture.?)
	} else {
		rl.EndTextureMode()
		append(&global.renderTextureStack, global.currentRenderTexture.?)
		global.currentRenderTexture = renderTexture
		rl.BeginTextureMode(global.currentRenderTexture.?)
	}
}
endNestedTextureMode :: proc() {
	g := global
	if global.currentRenderTexture == nil {
		panic("No render texture to pop off the stack")
	} else {
		rl.EndTextureMode()
		if len(global.renderTextureStack) == 0 {
			global.currentRenderTexture = nil
		} else {
			global.currentRenderTexture = pop(&global.renderTextureStack)
			rl.BeginTextureMode(global.currentRenderTexture.?)
		}
	}
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

	// TODO: Only ever explicitly pass gameAlloc so that long-term memory allocations are explicit
	// Currently this causes errors, I don't understand how this works apparently
	//context.allocator = mem.panic_allocator()
	init()
	defer deinit()

	context.allocator = global.frameAlloc
	context.temp_allocator = global.frameAlloc

	global.music = loadMusicStream(.KowloonSmokeBreak)
	rl.PlayMusicStream(global.music)

	global.player3D = createPlayer3D()
	global.elevator3D = createElevator3D()

	mem.dynamic_arena_reset(&global.frameArena)

	gameLoop()
}

gameLoop :: proc() {
	for !rl.WindowShouldClose() {
		if global.changeLevel {
			mem.dynamic_arena_reset(&global.levelArena)
			for object in global.gameObjects {
				object.destroyProc(object.data)
			}
			clear(&global.gameObjects)
			loadLevelProcs[global.levelIndex](global.levelAlloc)
			for object in global.gameObjects {
				object.startProc(object.data)
			}
			global.changeLevel = false
		}
		rl.UpdateMusicStream(global.music)

		debugModePrevious := global.debugMode
		if rl.IsKeyPressed(.BACKSPACE) {
			global.debugMode = global.debugMode ? false : true
		}
		currentCamera := &global.camera
		currentCamera3D := &global.camera3D
		if global.debugMode {
			if global.player3D.state != .Inactive && global.player3D.state != .Uninitialized {
				rl.UpdateCamera(&global.debugCamera3D, .FIRST_PERSON)
				if rl.IsKeyDown(.SPACE) {
					rl.CameraMoveUp(&global.debugCamera3D, 5.4 * TARGET_TIME_STEP)
				} else if rl.IsKeyDown(.LEFT_SHIFT) {
					rl.CameraMoveUp(&global.debugCamera3D, -5.4 * TARGET_TIME_STEP)
				}
				rl.DisableCursor()
				currentCamera3D = &global.debugCamera3D
			} else {
				if !debugModePrevious {
					global.debugCamera.offset = global.camera.offset
					global.debugCamera.target = global.camera.target
				}
				mouseWheelMovement := rl.GetMouseWheelMoveV()
				if rl.IsMouseButtonDown(.MIDDLE) {
					global.debugCamera.target -= rl.GetMouseDelta()
				}
				global.debugCamera.zoom += mouseWheelMovement.y * 0.02
				currentCamera = &global.debugCamera
			}
		}
		if global.cameraFollowPlayer {
			global.camera.offset =
				getObjectCenterAbsolute(global.player.object^) * -1.0 +
				{WINDOW_WIDTH, WINDOW_HEIGHT} / 2.0
		}

		rl.ClearBackground(rl.BLACK)
		rl.BeginDrawing()
		beginNestedTextureMode(global.gameRenderTexture)
		rl.ClearBackground({0, 0, 0, 0})
		rl.BeginMode2D(currentCamera^)
		drawSolids()
		{
			i := len(global.gameObjects) - 1
			for i >= 0 {
				global.gameObjects[i].updateProc(global.gameObjects[i].data)
				i -= 1
			}
			i = len(global.gameObjects) - 1
			for i >= 0 {
				global.gameObjects[i].drawProc(global.gameObjects[i].data)
				i -= 1
			}
			i = len(global.gameObjects) - 1
			for i >= 0 {
				global.gameObjects[i].drawEndProc(global.gameObjects[i].data)
				i -= 1
			}
		}
		rl.EndMode2D()
		endNestedTextureMode()
		drawRenderTextureScaledToScreenBuffer(global.gameRenderTexture)

		updatePlayer3D(&global.player3D)
		updateElevator3D(&global.elevator3D)

		beginNestedTextureMode(global.gameRenderTexture)
		rl.BeginMode3D(currentCamera3D^)

		rl.ClearBackground({0.0, 0.0, 0.0, 0.0})
		drawElevator3D(&global.elevator3D)
		rl.DrawGrid(10, 1.0)

		rl.EndMode3D()
		endNestedTextureMode()

		drawRenderTextureScaledToScreenBuffer(global.gameRenderTexture)
		debugDrawGlobalCamera3DInfo(currentCamera3D^, 4, 4)
		rl.EndDrawing()
		mem.dynamic_arena_reset(&global.frameArena)
	}
	for object in global.gameObjects {
		object.destroyProc(object.data)
	}
}
