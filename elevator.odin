package game
import rl "lib/raylib"
import "core:math"
import c "core:c/libc"

Elevator3DEnteringStateData :: struct {
	camMovementTween:  Tween,
	doorMovementTween: Tween,
}
Elevator3DInsideStateData :: struct {
	viewAngleTween: Tween,
	viewAngle:      f32,
	vertViewAngleTween: Tween,
	vertViewAngle: f32,
}
ElevatorModelMeshes :: enum {
    Walls,
    Floor,
    Ceiling,
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
	wallMaterial:      rl.Material,
	lightMaterial:     rl.Material,
	floorMaterial:     rl.Material,
	enteringStateData: Elevator3DEnteringStateData,
	insideStateData:   Elevator3DInsideStateData,
}
createElevator3D :: proc() -> Elevator3D {
    wallMaterial := rl.LoadMaterialDefault()
    wallMaterial.shader = getShader(.Lighting3D)
    rl.SetMaterialTexture(&wallMaterial, .ALBEDO, getTexture(.ElevatorWall3D))
    lightMaterial := rl.LoadMaterialDefault()
    lightMaterial.shader = getShader(.Lighting3D)
    rl.SetMaterialTexture(&lightMaterial, .ALBEDO, getTexture(.ElevatorLights3D))
    floorMaterial := rl.LoadMaterialDefault()
    floorMaterial.shader = getShader(.Lighting3D)

	return Elevator3D{
		mainModel = getModel(.Elevator),
		leftDoorModel = getModel(.ElevatorSlidingDoorLeft),
		rightDoorModel = getModel(.ElevatorSlidingDoorRight),
		state = .Invisible,
		wallMaterial = wallMaterial,
		lightMaterial = lightMaterial,
		floorMaterial = floorMaterial,
	}
}

drawElevator3D :: proc(e: ^Elevator3D) {
    transform := rl.MatrixIdentity()
    applyLightToShader(e.wallMaterial.shader)
    rl.DrawMesh(e.mainModel.meshes[ElevatorModelMeshes.Walls], e.wallMaterial, transform)
    applyLightToShader(e.floorMaterial.shader)
    rl.DrawMesh(e.mainModel.meshes[ElevatorModelMeshes.Floor], e.floorMaterial, transform)
    applyLightToShader(e.lightMaterial.shader)
    rl.DrawMesh(e.mainModel.meshes[ElevatorModelMeshes.Ceiling], e.lightMaterial, transform)
	rl.DrawModel(e.leftDoorModel, {0.0, 0.0, 0.0}, 1.0, rl.WHITE)
	rl.DrawModel(e.rightDoorModel, {0.0, 0.0, 0.0}, 1.0, rl.WHITE)
}
destroyElevator3D :: proc(e: ^Elevator3D) {
    unloadMaterialMapOnly(e.wallMaterial)
    unloadMaterialMapOnly(e.lightMaterial)
}
updateElevator3D :: proc(e: ^Elevator3D) {
	switch (e.state) {
	case .Invisible:
	case .Entering:
		camX := updateAndStepTween(&e.enteringStateData.camMovementTween).(f32)
		global.camera3D.position.x = camX
		global.camera3D.target.x = camX + 1.0
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
				TweenF32Range {e.insideStateData.vertViewAngle, 0.5},
				.InvExp,
				0.8,
				0.0
			)
		} else if rl.IsKeyPressed(.DOWN) {
		    e.insideStateData.vertViewAngleTween = createTween(
				TweenF32Range{e.insideStateData.vertViewAngle, 0.0},
				.InvExp,
				0.8,
				0.0
			)
		}
		e.insideStateData.vertViewAngle = updateAndStepTween(&e.insideStateData.vertViewAngleTween).(f32)

		global.camera3D.target = {
			global.camera3D.position.x + viewDirection.x,
			global.camera3D.position.y + e.insideStateData.vertViewAngle,
			global.camera3D.position.z + viewDirection.y,
		}
	case .Look:
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
	case .Look:
	}
}
enterElevator3D :: proc(e: ^Elevator3D) {
	if e.state == .Invisible {
		setElevator3DState(e, .Entering)
	}
}
