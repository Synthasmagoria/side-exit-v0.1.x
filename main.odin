package game

import "base:runtime"
import "core:c"
import libc "core:c/libc"
import "core:crypto/x25519"
import "core:fmt"
import "core:math"
import "core:math/linalg"
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
	global.collisionRectangles = make([dynamic]iRectangle, 0, 1000, global.gameAlloc)
	global.renderTextureStack = make([dynamic]rl.RenderTexture, 0, 5, global.gameAlloc)
	global.gameObjects = make([dynamic]GameObject, 0, 100, global.gameAlloc)
	global.gameObjectIdCounter = min(i32)
	global.levelIndex = .UnrulyLand
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
	// TODO: Debug switch on this
	mem.dynamic_arena_init(&global.gameArena)
	defer mem.dynamic_arena_free_all(&global.gameArena)
	global.gameAlloc = Alloc {
		data      = &global.gameArena,
		procedure = dynamicArenaAllocatorDebugProc_Game,
	} //mem.dynamic_arena_allocator(&global.gameArena)

	mem.dynamic_arena_init(&global.levelArena)
	defer mem.dynamic_arena_free_all(&global.levelArena)
	global.levelAlloc = Alloc {
		data      = &global.levelArena,
		procedure = dynamicArenaAllocatorDebugProc_Level,
	} //mem.dynamic_arena_allocator(&global.levelArena)

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
DEBUG_FONT_SIZE :: 12
getDebugFontSize :: proc() -> i32 {
	return i32(getScreenScale().x * DEBUG_FONT_SIZE)
}
debugDrawFrameTime :: proc(x: i32, y: i32) {
	debugFontSize := getDebugFontSize()
	frameTimeText := rl.TextFormat("Frame time: %fms", rl.GetFrameTime() * 1000.0)
	stringSize := rl.MeasureText(frameTimeText, debugFontSize)
	debugDrawTextOutline(frameTimeText, x - stringSize, y, debugFontSize, rl.WHITE, rl.BLACK)
}
debugDrawPlayerInfo :: proc(player: Player, x: i32, y: i32) {
	debugFontSize := getDebugFontSize()
	positionText := rl.TextFormat("Position: %s", vector2ToStringTemp(player.object.pos))
	dy := y
	debugDrawTextOutline(positionText, x, dy, debugFontSize, rl.WHITE, rl.BLACK)
	dy += debugFontSize
}
debugDrawGlobalCamera3DInfo :: proc(cam: rl.Camera3D, x: i32, y: i32) {
	dy := y
	debugFontSize := getDebugFontSize()
	debugDrawTextOutline(
		rl.TextFormat("pos: %s", vector3ToStringTemp(cam.position)),
		x,
		dy,
		debugFontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += debugFontSize
	debugDrawTextOutline(
		rl.TextFormat("target: %s", vector3ToStringTemp(cam.target)),
		x,
		dy,
		debugFontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += debugFontSize
	debugDrawTextOutline(
		rl.TextFormat("look: %s", vector3ToStringTemp(cam.target - cam.position)),
		x,
		dy,
		debugFontSize,
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
loadLevel :: proc(level: Level) {
	global.levelIndex = level
	global.changeLevel = true
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
	global.camera.offset = {0.0, 0.0}
	global.camera.target = {0.0, 0.0}
	loadLevelGeneral(levelAlloc)
	generateWorld({-64, -64, 128, 128}, -0.5, 0, 8.0)
	global.player.object.pos = {0.0, 0.0}
	global.elevator.object.pos = {0.0, 0.0}
	global.elevator.visible = true
	global.elevator.instant = false
	_ = createStarBackground(levelAlloc)
}

GENERATION_BLOCK_SIZE :: 16
generateCircleMask2D :: proc(radius: i32) -> [dynamic]byte {
	diameter := radius + radius
	maskLength := diameter * diameter
	mask := make([dynamic]byte, maskLength, maskLength)
	center := rl.Vector2{f32(radius) - 0.5, f32(radius) - 0.5}
	for i in 0 ..< maskLength {
		x := i % diameter
		y := i / diameter
		position := rl.Vector2{f32(x), f32(y)}
		distance := linalg.distance(center, position)
		mask[i] = u8(math.step(f32(radius) - 0.25, distance) == 1)
	}
	return mask
}
andMask2D :: proc(
	dest: ^[dynamic]byte,
	destWidth: i32,
	mask: [dynamic]byte,
	maskWidth: i32,
	maskPosition: iVector2,
) {
	assert(linalg.fract(f32(len(dest)) / f32(destWidth)) == 0.0)
	assert(linalg.fract(f32(len(mask)) / f32(maskWidth)) == 0.0)
	destArea := iRectangle{0, 0, destWidth, i32(len(dest)) / destWidth}
	maskArea := iRectangle{maskPosition.x, maskPosition.y, maskWidth, i32(len(mask)) / maskWidth}
	assert(maskArea.x + maskArea.width <= destArea.width)
	assert(maskArea.y + maskArea.height <= destArea.height)
	for x in 0 ..< maskArea.width {
		for y in 0 ..< maskArea.height {
			destX := x + maskArea.x
			destY := y + maskArea.y
			destIndex := destX + destY * destWidth
			dest[destIndex] &= mask[x + y * maskWidth]
		}
	}
}
printArray2D :: proc(array: [dynamic]$T, arrayWidth: i32) {
	assert(linalg.fract(f32(len(array)) / f32(arrayWidth)) == 0.0)
	rowCount := i32(len(array)) / arrayWidth
	for i in 0 ..< rowCount {
		fmt.println(array[i * arrayWidth:(i + 1) * arrayWidth])
	}
}
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
	spawnAreaRadius: i32 = 5
	spawnAreaMask := generateCircleMask2D(spawnAreaRadius)
	andMask2D(
		&blocks,
		area.width,
		spawnAreaMask,
		spawnAreaRadius + spawnAreaRadius,
		{area.width / 2 - spawnAreaRadius, area.height / 2 - spawnAreaRadius},
	)
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
	camera = {zoom = 1.0},
	debugCamera = {zoom = 1.0},
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

debugPrintDynamicArenaAllocMessage :: proc(
	allocatorType: string,
	mode: mem.Allocator_Mode,
	loc: runtime.Source_Code_Location,
) {
	fmt.println(
		"(",
		allocatorType,
		")",
		mode,
		"at L:",
		loc.line,
		"C:",
		loc.column,
		"in",
		loc.procedure,
		"(",
		loc.file_path,
		")",
	)
}
dynamicArenaAllocatorDebugProc_Level :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size: int,
	alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> (
	[]byte,
	mem.Allocator_Error,
) {
	debugPrintDynamicArenaAllocMessage("level", mode, loc)
	return mem.dynamic_arena_allocator_proc(
		allocator_data,
		mode,
		size,
		alignment,
		old_memory,
		old_size,
	)
}
dynamicArenaAllocatorDebugProc_Game :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size: int,
	alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> (
	[]byte,
	mem.Allocator_Error,
) {
	debugPrintDynamicArenaAllocMessage("game", mode, loc)
	return mem.dynamic_arena_allocator_proc(
		allocator_data,
		mode,
		size,
		alignment,
		old_memory,
		old_size,
	)
}

audioProcessEffectLPF :: proc "c" (buffer: rawptr, frames: c.uint) {
	low: [2]f32 = {0.0, 0.0}
	cutoff: f32 = 70.0 / 44100.0
	k := cutoff / (cutoff + 0.159154931)

	bufferData := cast([^]c.float)buffer
	for i: c.uint = 0; i < frames * 2; i += 2 {
		l := bufferData[i]
		r := bufferData[i + 1]
		low[0] += k * (l - low[0])
		low[1] += k * (r - low[1])
		bufferData[i] = low[0]
		bufferData[i + 1] = low[1]
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
		@(static) isLowPass := false
		if rl.IsKeyPressed(.H) {
			isLowPass = !isLowPass
			if isLowPass {
				rl.AttachAudioStreamProcessor(global.music.stream, audioProcessEffectLPF)
			} else {
				rl.DetachAudioStreamProcessor(global.music.stream, audioProcessEffectLPF)
			}
		}
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

		g := global

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
		if global.player3D.state != .Inactive {
			debugDrawGlobalCamera3DInfo(currentCamera3D^, 4, 4)
		} else {
			debugDrawPlayerInfo(global.player^, 4, 4)
		}
		debugDrawFrameTime(rl.GetScreenWidth() - 4, 4)
		rl.EndDrawing()
		mem.dynamic_arena_reset(&global.frameArena)
	}
	for object in global.gameObjects {
		object.destroyProc(object.data)
	}
}
