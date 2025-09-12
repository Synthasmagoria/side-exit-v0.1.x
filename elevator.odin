package game
import rl "lib/raylib"
import "core:math"

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
createElevator3D :: proc() -> Elevator3D {
	return Elevator3D{
		mainModel = getModel(.Elevator),
		leftDoorModel = getModel(.ElevatorSlidingDoorLeft),
		rightDoorModel = getModel(.ElevatorSlidingDoorRight),
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
		global.camera3D.target = {
			global.camera3D.position.x + viewDirection.x,
			global.camera3D.position.y,
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
	case .Look:
	}
}
enterElevator3D :: proc(e: ^Elevator3D) {
	if e.state == .Invisible {
		setElevator3DState(e, .Entering)
	}
}
