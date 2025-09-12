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
globalCamera := rl.Camera2D {
	offset   = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
	target   = {0.0, 0.0},
	rotation = 0.0,
	zoom     = 1.0,
}

globalCamera3D := rl.Camera3D {
	position   = {0.0, 2.0, 0.0},
	target     = {1.0, 2.0, 0.0},
	up         = {0.0, 1.0, 0.0},
	fovy       = 90.0,
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

Elevator3DEnteringStateData :: struct {
	camMovementTween:  Tween,
	doorMovementTween: Tween,
}
Elevator3DInsideStateData :: struct {
	viewAngleTween: Tween,
	viewAngle:      f32,
}
Elevator3DState :: enum {
	Invisible,
	Entering,
	Inside,
	Look,
}
Elevator3D :: struct {
	mainModel:         rl.Model,
	leftDoorModel:     rl.Model,
	rightDoorModel:    rl.Model,
	state:             Elevator3DState,
	enteringStateData: Elevator3DEnteringStateData,
	insideStateData:   Elevator3DInsideStateData,
}
globalElevator3D: Elevator3D
createElevator3D :: proc(
	mainModel: rl.Model,
	leftDoorModel: rl.Model,
	rightDoorModel: rl.Model,
) -> Elevator3D {
	return {
		mainModel = mainModel,
		leftDoorModel = leftDoorModel,
		rightDoorModel = rightDoorModel,
		state = .Invisible,
	}
}
drawElevator3D :: proc(e: ^Elevator3D) {
	rl.DrawModel(e.mainModel, {0.0, 0.0, 0.0}, 1.0, rl.WHITE)
	rl.DrawModel(e.leftDoorModel, {0.0, 0.0, 0.0}, 1.0, rl.WHITE)
	rl.DrawModel(e.rightDoorModel, {0.0, 0.0, 0.0}, 1.0, rl.WHITE)
}
updateElevator3D :: proc(e: ^Elevator3D) {
	switch (e.state) {
	case .Invisible:
	case .Entering:
		camX := updateAndStepTween(&e.enteringStateData.camMovementTween).(f32)
		globalCamera3D.position.x = camX
		globalCamera3D.target.x = camX + 1.0
		doorZ := updateAndStepTween(&e.enteringStateData.doorMovementTween).(f32)
		e.leftDoorModel.transform = rl.MatrixTranslate(0.0, 0.0, doorZ)
		e.rightDoorModel.transform = rl.MatrixTranslate(0.0, 0.0, -doorZ)
		if tweenIsFinished(e.enteringStateData.camMovementTween) &&
		   tweenIsFinished(e.enteringStateData.doorMovementTween) {
			setElevator3DState(e, .Inside)
		}
	case .Inside:
		if rl.IsKeyPressed(.LEFT) {
			e.insideStateData.viewAngleTween = createTween(
				TweenF32Range {
					e.insideStateData.viewAngle,
					e.insideStateData.viewAngleTween.range.(TweenF32Range).to - math.TAU / 4,
				},
				.InvExp,
				0.8,
				0.0,
			)
		} else if rl.IsKeyPressed(.RIGHT) {
			e.insideStateData.viewAngleTween = createTween(
				TweenF32Range {
					e.insideStateData.viewAngle,
					e.insideStateData.viewAngleTween.range.(TweenF32Range).to + math.TAU / 4,
				},
				.InvExp,
				0.8,
				0.0,
			)
		}
		e.insideStateData.viewAngle = updateAndStepTween(&e.insideStateData.viewAngleTween).(f32)
		viewDirection := rl.Vector2Rotate(rl.Vector2{1.0, 0.0}, e.insideStateData.viewAngle)
		globalCamera3D.target = {
			globalCamera3D.position.x + viewDirection.x,
			globalCamera3D.position.y,
			globalCamera3D.position.z + viewDirection.y,
		}
	case .Look:
	}
}
setElevator3DState :: proc(e: ^Elevator3D, state: Elevator3DState) {
	if e.state == state {
		return
	}
	e.state = state
	fmt.println(e.state)
	switch e.state {
	case .Invisible:
	case .Entering:
		e.enteringStateData.camMovementTween = createTween(TweenF32Range{4.0, 0.0}, .InvExp, 2.0)
		e.enteringStateData.doorMovementTween = createTween(
			TweenF32Range{2.0, 0.0},
			.Linear,
			1.0,
			0.5,
		)
	case .Inside:
		e.insideStateData.viewAngleTween = createFinishedTween(TweenF32Range{0.0, 0.0})
	case .Look:
	}
}
enterElevator3D :: proc(e: ^Elevator3D) {
	if e.state == .Invisible {
		setElevator3DState(e, .Entering)
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
	globalElevator3D = createElevator3D(
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

		// rl.UpdateCamera(&globalCamera3D, .FIRST_PERSON)

		if rl.IsKeyPressed(.BACKSPACE) {
			enterElevator3D(&globalElevator3D)
		}
		updateElevator3D(&globalElevator3D)

		rl.BeginTextureMode(renderTex3D)
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(globalCamera3D)
		rl.ClearBackground({0.0, 0.0, 0.0, 0.0})
		rl.DrawGrid(10, 1.0)
		drawElevator3D(&globalElevator3D)
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
