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

init :: proc() {
	initEngine()
	loadModels()
	loadTextures()
	loadShaders()
	loadSounds()
	initSpriteDefs()
	initLights()
	initLoadLevelProcs()
	engine.defaultMaterial3D = loadPassthroughMaterial3D()
	global.levelIndex = .TitleMenu
	global.changeLevel = true
}

deinit :: proc() {
	unloadModels()
	unloadTextures()
	unloadShaders()
	unloadSounds()
	deinitEngine()
}

initLights :: proc() {
	engine.ambientLightingColor = {0.1, 0.1, 0.12, 1.0}
	engine.lights3D[0] = Light3D {
		enabled  = 1,
		type     = .Point,
		position = {0.0, 3.0, 0.0},
		target   = {0.0, 0.0, 0.0},
		color    = {1.0, 1.0, 1.0, 1.0},
	}
	engine.lights3D[1] = Light3D {
		enabled  = 0,
		type     = .Point,
		position = {0.0, 0.0, 0.0},
		target   = {0.0, 0.0, 0.0},
		color    = {1.0, 1.0, 1.0, 1.0},
	}
	engine.lights3D[2] = Light3D {
		enabled  = 0,
		type     = .Point,
		position = {0.0, 0.0, 0.0},
		target   = {0.0, 0.0, 0.0},
		color    = {1.0, 1.0, 1.0, 1.0},
	}
	engine.lights3D[3] = Light3D {
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
	TitleMenu,
	Hub,
	UnrulyLand,
	_Count,
}
loadLevelProcs: [Level._Count]proc(_: mem.Allocator)
initLoadLevelProcs :: proc() {
	loadLevelProcs[Level.TitleMenu] = loadLevel_TitleMenu
	loadLevelProcs[Level.Hub] = loadLevel_Hub
	loadLevelProcs[Level.UnrulyLand] = loadLevel_UnrulyLand
}
loadLevel :: proc(level: Level) {
	global.levelIndex = level
	global.changeLevel = true
}
GeneralLevelObjects :: struct {
	player:   ^Player,
	elevator: ^Elevator,
}
loadLevelGeneral :: proc(levelAlloc: mem.Allocator) -> GeneralLevelObjects {
	elevator := createElevator(levelAlloc)
	elevator.object.pos = {0.0, 56.0}
	player := createPlayer(levelAlloc)
	return {player, elevator}
}
loadLevel_TitleMenu :: proc(levelAlloc: mem.Allocator) {
	global.cameraFollowPlayer = false
	global.camera = getZeroCamera2D()
	global.camera3D = getZeroCamera3D()
	setElevator3DState(&global.elevator3D, .Invisible)
	_ = createTitleMenu(levelAlloc)
	_ = createTitleMenuBackground(levelAlloc)
}
loadLevel_Hub :: proc(levelAlloc: mem.Allocator) {
	global.cameraFollowPlayer = false
	global.camera.target = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	global.camera.offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	generalObjects := loadLevelGeneral(levelAlloc)
	_ = createHubGraphics(levelAlloc)
	generalObjects.player.object.pos = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}
	generalObjects.elevator.object.pos = {146.0, 181.0}
	generalObjects.elevator.visible = false
	generalObjects.elevator.instant = true

	append(&engine.collisionRectangles, iRectangle{47, 0, 10, 237})
	append(&engine.collisionRectangles, iRectangle{47, 237, 382, 11})
	append(&engine.collisionRectangles, iRectangle{419, 0, 8, 236})
}
loadLevel_UnrulyLand :: proc(levelAlloc: mem.Allocator) {
	global.cameraFollowPlayer = true
	global.camera.offset = {0.0, 0.0}
	global.camera.target = {0.0, 0.0}
	generalObjects := loadLevelGeneral(levelAlloc)
	generateWorld({-64, -64, 128, 128}, -0.5, 0, 8.0)
	generalObjects.player.object.pos = {0.0, 0.0}
	generalObjects.elevator.object.pos = {0.0, 0.0}
	generalObjects.elevator.visible = true
	generalObjects.elevator.instant = false
	_ = createStarBackground(levelAlloc)
}

Global :: struct {
	levelIndex:         Level,
	changeLevel:        bool,
	camera:             rl.Camera2D,
	cameraFollowPlayer: bool,
	camera3D:           rl.Camera3D,
	player3D:           Player3D,
	elevator3D:         Elevator3D,
	debugCamera:        rl.Camera2D,
	debugCamera3D:      rl.Camera3D,
	debugMode:          bool,
	music:              rl.Music,
	windowCloseRequest: bool,
}
global := Global {
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
	rl.SetTraceLogLevel(.INFO)
	rl.SetTargetFPS(TARGET_FPS)
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Elevator Game")
	defer rl.CloseWindow()

	// TODO: Only ever explicitly pass gameAlloc so that long-term memory allocations are explicit
	// Currently this causes errors, I don't understand how this works apparently
	//context.allocator = mem.panic_allocator()
	init()
	context.allocator = engine.frameAlloc
	context.temp_allocator = engine.frameAlloc
	defer deinit()

	global.music = loadMusicStream(.KowloonSmokeBreak)
	rl.PlayMusicStream(global.music)
	mem.dynamic_arena_reset(&engine.frameArena)

	global.player3D = createPlayer3D()
	global.elevator3D = createElevator3D()

	for !rl.WindowShouldClose() && !global.windowCloseRequest {
		gameStep()
	}

	for i in 0 ..< len(engine.gameObjects) {
		engine.gameObjects[i].destroyProc(engine.gameObjects[i].data)
	}
}

gameStep :: proc() {
	player := getFirstGameObjectOfType(Player)
	elevator := getFirstGameObjectOfType(Elevator)

	if global.changeLevel {
		destroyAllGameObjects()
		mem.dynamic_arena_reset(&engine.levelArena)
		loadLevelProcs[global.levelIndex](engine.levelAlloc)
		for object in engine.gameObjects {
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
	if global.cameraFollowPlayer && player != nil {
		global.camera.offset =
			getObjectCenterAbsolute(player.object^) * -1.0 + {WINDOW_WIDTH, WINDOW_HEIGHT} / 2.0
	}

	if rl.IsKeyPressed(.A) {
		if stars := getFirstGameObjectOfType(StarBg); stars != nil {
			destroyGameObject(stars.object.id)
		} else {
			_ = createStarBackground(engine.levelAlloc)
		}
	}

	rl.ClearBackground(rl.BLACK)
	rl.BeginDrawing()
	beginModeStacked(currentCamera^, engine.renderTexture)
	rl.ClearBackground({0, 0, 0, 0})
	for object in engine.gameObjects {
		object.updateProc(object.data)
	}
	for object in engine.gameObjectsDepthOrdered {
		object.drawProc(object.data)
	}
	for object in engine.gameObjectsDepthOrdered {
		object.drawEndProc(object.data)
	}
	endModeStacked()

	drawRenderTextureScaledToScreenBuffer(engine.renderTexture)

	beginModeStacked(currentCamera3D^, engine.renderTexture)
	rl.ClearBackground({0.0, 0.0, 0.0, 0.0})
	if global.debugMode {
		rl.DrawGrid(10, 1.0)
	}
	updateElevator3D(&global.elevator3D)
	updatePlayer3D(&global.player3D)
	for object in engine.gameObjects {
		object.draw3DProc(object.data)
	}
	drawElevator3D(&global.elevator3D)
	endModeStacked()

	drawRenderTextureScaledToScreenBuffer(engine.renderTexture)

	if player != nil {
		if global.player3D.state != .Inactive {
			debugDrawGlobalCamera3DInfo(currentCamera3D^, 4, 4)
		} else {
			debugDrawPlayerInfo(player^, 4, 4)
		}
	}
	debugDrawFrameTime(rl.GetScreenWidth() - 4, 4)

	rl.EndDrawing()
	mem.dynamic_arena_reset(&engine.frameArena)
}
