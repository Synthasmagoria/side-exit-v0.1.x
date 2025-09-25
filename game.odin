package game

import "base:runtime"
import "core:c"
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
	global.musicLPFFrequency = 44100.0
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
		color    = {0.5, 0.5, 0.5, 1.0},
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
	_ = createTitleMenu(levelAlloc)
	_ = createTitleMenuBackground(levelAlloc)
}
loadLevel_Hub :: proc(levelAlloc: mem.Allocator) {
	global.cameraFollowPlayer = false
	global.camera.target = {RENDER_TEXTURE_WIDTH_2D / 2, RENDER_TEXTURE_HEIGHT_2D / 2}
	global.camera.offset = {RENDER_TEXTURE_WIDTH_2D / 2, RENDER_TEXTURE_HEIGHT_2D / 2}
	generalObjects := loadLevelGeneral(levelAlloc)
	_ = createHubGraphics(levelAlloc)
	generalObjects.player.object.pos = {RENDER_TEXTURE_WIDTH_2D / 2, RENDER_TEXTURE_HEIGHT_2D / 2}
	generalObjects.elevator.object.pos = {146.0, 151.0}
	generalObjects.elevator.visible = false
	generalObjects.elevator.object.colRec.height += 10.0
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

	collisionBitmask := generateWorldCollisionBitmask({-64, -64, 128, 128}, -0.2, 0, 8.0)
	generateElevatorSpawnAreaInCollisionBitmaskCenter(&collisionBitmask, 9)
	generalObjects.elevator.object.pos = getElevatorWorldCenterPosition(generalObjects.elevator^, collisionBitmask)
	generalObjects.elevator.visible = true
	generalObjects.elevator.instant = false
	addElevatorPlatformToCollisionBitmask(&collisionBitmask, generalObjects.elevator^)
	addWorldCollisionBitmaskToCollision(collisionBitmask)

	//generalObjects.player.object.pos = generalObjects.elevator.object.pos
	_ = createUnrulyLandGraphics(levelAlloc)
}

Camera3D :: struct {
	shakeOffset: rl.Vector3,
	position:    rl.Vector3,
	target:      rl.Vector3,
	_camera:     rl.Camera3D,
}

Global :: struct {
	levelIndex:         Level,
	changeLevel:        bool,
	camera:             rl.Camera2D,
	cameraFollowPlayer: bool,
	camera3D:           Camera3D,
	player3D:           Player3D,
	elevator3D:         Elevator3D,
	debugCamera:        rl.Camera2D,
	debugCamera3D:      Camera3D,
	debugMode:          bool,
	music:              rl.Music,
	musicLPFFrequency:  f32,
	windowCloseRequest: bool,
}
global := Global {
	camera        = getZeroCamera2D(),
	debugCamera   = getZeroCamera2D(),
	camera3D      = getZeroCamera3D(),
	debugCamera3D = getZeroCamera3D(),
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
	return mem.dynamic_arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size)
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
	return mem.dynamic_arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size)
}

audioProcessEffectLPF :: proc "c" (buffer: rawptr, frames: c.uint) {
	@(static) low: [2]f32 = {0.0, 0.0}
	cutoff: f32 = global.musicLPFFrequency / 44100.0
	k: f32 = cutoff / (cutoff + 0.159154931)

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

initRaylib :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE}) // TODO: Remove artifacts from main framebuffer when resizing
	when ODIN_DEBUG {
		rl.SetTraceLogLevel(.WARNING)
	} else {
		rl.SetTraceLogLevel(.ERROR)
	}
	rl.SetTargetFPS(TARGET_FPS)
	rl.InitAudioDevice()
	rl.InitWindow(RENDER_TEXTURE_WIDTH_3D, RENDER_TEXTURE_HEIGHT_3D, "Elevator Game")
}

deinitRaylib :: proc() {
	rl.CloseWindow()
	rl.CloseAudioDevice()
}

setGameGlobals :: proc() {
	global.player3D = createPlayer3D()
	global.elevator3D = createElevator3D()
}

gameStep :: proc() {
	player := getFirstGameObjectOfType(Player)
	elevator := getFirstGameObjectOfType(Elevator)

	if global.changeLevel {
		destroyAllGameObjects()
		clear(&engine.collisionRectangles)
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
			rl.UpdateCamera(&global.debugCamera3D._camera, .FIRST_PERSON)
			if rl.IsKeyDown(.SPACE) {
				rl.CameraMoveUp(&global.debugCamera3D._camera, 5.4 * TARGET_TIME_STEP)
			} else if rl.IsKeyDown(.LEFT_SHIFT) {
				rl.CameraMoveUp(&global.debugCamera3D._camera, -5.4 * TARGET_TIME_STEP)
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
			getObjectCenterAbsolute(player.object^) * -1.0 + {RENDER_TEXTURE_WIDTH_2D, RENDER_TEXTURE_HEIGHT_2D} / 2.0
	}

	rl.ClearBackground(rl.BLACK)
	rl.BeginDrawing()
	beginModeStacked(currentCamera^, engine.renderTexture2D)
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

	drawRenderTextureScaledToScreenBuffer(engine.renderTexture2D)

	beginModeStacked(currentCamera3D, engine.renderTexture3D)
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

	drawRenderTextureScaledToScreenBuffer(engine.renderTexture3D)

	if player != nil {
		if global.player3D.state != .Inactive {
			debugDrawGlobalCamera3DInfo(currentCamera3D._camera, 4, 4)
		} else {
			debugDrawPlayerInfo(player^, 4, 4)
		}
	}
	debugDrawFrameTime(rl.GetScreenWidth() - 4, 4)

	rl.EndDrawing()
	mem.dynamic_arena_reset(&engine.frameArena)
}
