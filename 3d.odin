package game
import c "core:c/libc"
import "core:fmt"
import "core:math"
import rl "lib/raylib"

FORWARD_3D :: rl.Vector3{1.0, 0.0, 0.0} // out of elevator
BACKWARD_3D :: rl.Vector3{-1.0, 0.0, 0.0} // into elevator
LEFT_3D :: rl.Vector3{0.0, 0.0, -1.0}
RIGHT_3D :: rl.Vector3{0.0, 0.0, 1.0}
UP_3D :: rl.Vector3{0.0, 1.0, 0.0}
DOWN_3D :: rl.Vector3{0.0, -1.0, 0.0}

MatrixRotateRoll :: rl.MatrixRotateX
MatrixRotateYaw :: rl.MatrixRotateY
MatrixRotatePitch :: rl.MatrixRotateZ

PLAYER_HEIGHT_3D :: rl.Vector3{0.0, 2.0, 0.0}
PLAYER_3D_OUTSIDE_POSITION :: rl.Vector3{5.0, 2.0, 0.0}
PLAYER_3D_INSIDE_POSITION :: PLAYER_HEIGHT_3D

Player3DState :: enum {
    Uninitialized,
    Inactive,
    Looking,
    Moving,
}
Player3D :: struct {
    state: Player3DState,
    movingStateData: Player3DMovingStateData,
    yaw: f32,
    pitch: f32,
}
Player3DMovingStateData :: struct {
    movementTween: Tween,
    nextState: Player3DState,
    look: rl.Vector3,
}
Player3DLookingStateData :: struct {

}
createPlayer3D :: proc() -> Player3D {
    player := Player3D{}
    setPlayer3DState(&player, .Inactive)
    return player
}
setPlayer3DState :: proc(player: ^Player3D, nextState: Player3DState) {
    if player.state == nextState {
        return
    }
    player.state = nextState
    fmt.println(player.state)
    switch player.state {
    case .Uninitialized:
    case .Inactive:
        global.camera3D.position = PLAYER_3D_OUTSIDE_POSITION
        global.camera3D.target = global.camera3D.position + FORWARD_3D
    case .Looking:
    case .Moving:
    }
}
player3DApplyCameraRotation :: proc(player: ^Player3D) {
    global.camera3D.target =
        global.camera3D.position +
        rl.Vector3Transform(FORWARD_3D, MatrixRotatePitch(player.pitch) * MatrixRotateYaw(player.yaw))
}
updatePlayer3D :: proc(player: ^Player3D) {
    switch player.state {
    case .Uninitialized:
    case .Inactive:
    case .Looking:
        player3DApplyCameraRotation(player)
    case .Moving:
        global.camera3D.position = updateAndStepTween(&player.movingStateData.movementTween).(rl.Vector3)
        global.camera3D.target = global.camera3D.position + player.movingStateData.look
        if tweenIsFinished(player.movingStateData.movementTween) {
            setPlayer3DState(player, player.movingStateData.nextState)
        }
    }
}
movePlayer3D :: proc(player: ^Player3D, from: rl.Vector3, to: rl.Vector3, nextState: Player3DState) {
    assert(nextState != .Moving && nextState != .Uninitialized)
    if nextState == player.state {
        return
    }
    player.movingStateData = {
        movementTween = createTween(TweenVector3Range{from, to}, .InvExp, 1.0),
        look = global.camera3D.target - global.camera3D.position,
        nextState = nextState
    }
    setPlayer3DState(player, .Moving)
}

Elevator3DEnteringStateData :: struct {
	camMovementTween:  Tween,
	doorMovementTween: Tween,
}
Elevator3DInsideStateData :: struct {
	viewAngleTween:     Tween,
	viewAngle:          f32,
	vertViewAngleTween: Tween,
	vertViewAngle:      f32,
}
Elevator3DMoveState :: struct {
	nextState:     Elevator3DState,
	movementTween: Tween,
}
Elevator3DPanelStateData :: struct {
	camMovementTween: Tween,
	nextState:        Elevator3DState,
}
Elevator3DModelMeshes :: enum {
	Walls,
	Floor,
	Ceiling,
	Panel,
}
Elevator3DState :: enum {
	Invisible,
	Entering,
	Inside,
	ToPanel,
	Panel,
	FromPanel,
}
Elevator3D :: struct {
	mainModel:         rl.Model,
	leftDoorModel:     rl.Model,
	rightDoorModel:    rl.Model,
	state:             Elevator3DState,
	wallMaterial:      rl.Material,
	lightMaterial:     rl.Material,
	floorMaterial:     rl.Material,
	insideElevatorPos: rl.Vector3,
	lightFrameIndex:   f32,
	enteringStateData: Elevator3DEnteringStateData,
	insideStateData:   Elevator3DInsideStateData,
	panelStateData:    Elevator3DPanelStateData,
}
createElevator3D :: proc() -> Elevator3D {
	lightMaterial := rl.LoadMaterialDefault()
	lightMaterial.shader = getShader(.AnimatedTexture3D)
	rl.SetMaterialTexture(&lightMaterial, .ALBEDO, getTexture(.ElevatorLights3D))

	return Elevator3D {
		mainModel = getModel(.Elevator),
		leftDoorModel = getModel(.ElevatorSlidingDoorLeft),
		rightDoorModel = getModel(.ElevatorSlidingDoorRight),
		state = .Invisible,
		wallMaterial = loadPassthroughMaterial3D(getTexture(.ElevatorWall3D)),
		lightMaterial = lightMaterial,
		floorMaterial = loadPassthroughMaterial3D(),
	}
}
toggleElevatorLights :: proc(e: ^Elevator3D) {
	if e.lightFrameIndex == 0.0 {
		e.lightFrameIndex = 1.0
	} else {
		e.lightFrameIndex = 0.0
	}
	setLightStatus(i32(e.lightFrameIndex))
}
movePlayerInsideElevator :: proc(e: ^Elevator3D, to: Elevator3DState) {

}
drawElevator3D :: proc(e: ^Elevator3D) {
	transform := rl.MatrixIdentity()
	applyLightToShader(e.wallMaterial.shader)
	rl.DrawMesh(e.mainModel.meshes[Elevator3DModelMeshes.Walls], e.wallMaterial, transform)

	applyLightToShader(e.floorMaterial.shader)
	setShaderValue(e.lightMaterial.shader, "frameIndex", &e.lightFrameIndex)
	lightFrameCount: int = 2
	setShaderValue(e.lightMaterial.shader, "frameCount", &lightFrameCount)
	rl.DrawMesh(e.mainModel.meshes[Elevator3DModelMeshes.Floor], e.floorMaterial, transform)

	applyLightToShader(e.lightMaterial.shader)
	rl.DrawMesh(e.mainModel.meshes[Elevator3DModelMeshes.Ceiling], e.lightMaterial, transform)

	applyLightToShader(global.defaultMaterial3D.shader)
	rl.DrawMesh(
		e.mainModel.meshes[Elevator3DModelMeshes.Panel],
		global.defaultMaterial3D,
		transform,
	)
	rl.DrawMesh(e.leftDoorModel.meshes[0], global.defaultMaterial3D, e.leftDoorModel.transform)
	rl.DrawMesh(e.rightDoorModel.meshes[0], global.defaultMaterial3D, e.rightDoorModel.transform)
}
destroyElevator3D :: proc(e: ^Elevator3D) {
	unloadMaterialMapOnly(e.wallMaterial)
	unloadMaterialMapOnly(e.lightMaterial)
	unloadMaterialMapOnly(e.floorMaterial)
}
updateElevator3D :: proc(e: ^Elevator3D) {
	if rl.IsKeyPressed(.L) {
		toggleElevatorLights(e)
	}
	switch (e.state) {
	case .Invisible:
	case .Entering:
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
		if rl.IsKeyPressed(.UP) {
			e.insideStateData.vertViewAngleTween = createTween(
				TweenF32Range{e.insideStateData.vertViewAngle, 0.5},
				.InvExp,
				0.8,
			)
		} else if rl.IsKeyPressed(.DOWN) {
			e.insideStateData.vertViewAngleTween = createTween(
				TweenF32Range{e.insideStateData.vertViewAngle, 0.0},
				.InvExp,
				0.8,
			)
		}
		e.insideStateData.vertViewAngle =
		updateAndStepTween(&e.insideStateData.vertViewAngleTween).(f32)

		global.camera3D.target = {
			global.camera3D.position.x + viewDirection.x,
			global.camera3D.position.y + e.insideStateData.vertViewAngle,
			global.camera3D.position.z + viewDirection.y,
		}
	case .ToPanel:
		global.camera3D.position =
		updateAndStepTween(&e.panelStateData.camMovementTween).(rl.Vector3)
		global.camera3D.target = global.camera3D.position + {1.0, 0.0, 0.0}
		if tweenIsFinished(e.panelStateData.camMovementTween) {
			setElevator3DState(e, .Panel)
		}
	case .Panel:
	case .FromPanel:
	}
}
setElevator3DState :: proc(e: ^Elevator3D, state: Elevator3DState) {
	if e.state == state {
		return
	}
	e.state = state
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
		e.insideStateData.vertViewAngleTween = createFinishedTween(TweenF32Range{0.0, 0.0})
	case .ToPanel:
		e.panelStateData.camMovementTween = createTween(
			TweenVector3Range{global.camera3D.position, {2.1, 2.3, 2.3}},
			.InvExp,
			0.5,
		)
	case .Panel:
	case .FromPanel:
	}
}
enterElevator3D :: proc(e: ^Elevator3D) {
	if e.state == .Invisible {
		setElevator3DState(e, .Entering)
	}
}
