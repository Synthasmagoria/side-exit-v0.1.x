package game
import c "core:c/libc"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:reflect"
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
PLAYER_3D_PANEL_POSITION :: rl.Vector3{2.225, 2.35, 2.225}
PLAYER_3D_LOOKING_VERTICAL_ANGLE_INCREMENT: f32 : math.PI / 3.0
PLAYER_3D_LOOKING_HORIZONTAL_ANGLE_INCREMENT: f32 : math.PI / 2.0

Player3DState :: enum {
	Uninitialized,
	Inactive,
	Looking,
	Moving,
	Panel,
}
Player3D :: struct {
	state:            Player3DState,
	movingStateData:  Player3DMovingStateData,
	lookingStateData: Player3DLookingStateData,
	yaw:              f32,
	pitch:            f32,
}
Player3DMovingStateData :: struct {
	movementTween: Tween,
	nextState:     Player3DState,
	look:          rl.Vector3,
}
PLAYER_3D_LOOKING_HORIZONTAL_DURATION :: 0.5
PLAYER_3D_LOOKING_VERTICAL_DURATION :: 0.4
PlayerLookingStateHorizontal :: enum {
	Forward,
	Right,
	Backward,
	Left,
}
PlayerLookingStateVertical :: enum {
	Down,
	Middle,
	Up,
}
Player3DLookingStateData :: struct {
	yawTween:        Tween,
	horizontalState: PlayerLookingStateHorizontal,
	pitchTween:      Tween,
	verticalState:   PlayerLookingStateVertical,
}
createPlayer3D :: proc() -> Player3D {
	player := Player3D {
		lookingStateData = {
			yawTween = createFinishedTween(0.0),
			pitchTween = createFinishedTween(0.0),
			horizontalState = .Forward,
			verticalState = .Middle,
		},
	}
	setPlayer3DState(&player, .Inactive)
	return player
}
setPlayer3DState :: proc(player: ^Player3D, nextState: Player3DState) {
	if player.state == nextState {
		return
	}
	player.state = nextState
	switch player.state {
	case .Uninitialized:
	case .Inactive:
		global.camera3D.position = PLAYER_3D_OUTSIDE_POSITION
		player3DApplyCameraRotation(player)
	case .Looking:
		player.lookingStateData.yawTween = createFinishedTween(player.yaw)
		player.lookingStateData.pitchTween = createFinishedTween(player.pitch)
	case .Moving:
	case .Panel:
	}
}
player3DApplyCameraRotation :: proc(player: ^Player3D) {
	global.camera3D.target =
		global.camera3D.position +
		rl.Vector3Transform(
			FORWARD_3D,
			MatrixRotateYaw(player.yaw) * MatrixRotatePitch(player.pitch),
		)
}
updatePlayer3D :: proc(player: ^Player3D) {
	switch player.state {
	case .Uninitialized:
	case .Inactive:
	case .Looking:
		data := &player.lookingStateData
		if rl.IsKeyPressed(.LEFT) {
			goalYaw := data.yawTween.range.(TweenF32Range).to
			data.yawTween = createTween(
				TweenF32Range{player.yaw, goalYaw + PLAYER_3D_LOOKING_HORIZONTAL_ANGLE_INCREMENT},
				.InvExp,
				PLAYER_3D_LOOKING_HORIZONTAL_DURATION,
			)
			data.horizontalState = enumNext(data.horizontalState)
		} else if rl.IsKeyPressed(.RIGHT) {
			goalYaw := data.yawTween.range.(TweenF32Range).to
			data.yawTween = createTween(
				TweenF32Range{player.yaw, goalYaw - PLAYER_3D_LOOKING_HORIZONTAL_ANGLE_INCREMENT},
				.InvExp,
				PLAYER_3D_LOOKING_HORIZONTAL_DURATION,
			)
			data.horizontalState = enumPrev(data.horizontalState)
		}
		player.yaw = updateAndStepTween(&data.yawTween).(f32)

		if rl.IsKeyPressed(.UP) && !isEnumLast(data.verticalState) {
			data.verticalState = enumNext(data.verticalState)
			angleIncrement := PLAYER_3D_LOOKING_VERTICAL_ANGLE_INCREMENT
			data.pitchTween = createTween(
				TweenF32Range {
					player.pitch,
					-angleIncrement + angleIncrement * f32(data.verticalState),
				},
				.InvExp,
				PLAYER_3D_LOOKING_VERTICAL_DURATION,
			)
		} else if rl.IsKeyPressed(.DOWN) && !isEnumFirst(data.verticalState) {
			data.verticalState = enumPrev(data.verticalState)
			angleIncrement := PLAYER_3D_LOOKING_VERTICAL_ANGLE_INCREMENT
			data.pitchTween = createTween(
				TweenF32Range {
					player.pitch,
					-angleIncrement + angleIncrement * f32(data.verticalState),
				},
				.InvExp,
				PLAYER_3D_LOOKING_VERTICAL_DURATION,
			)
		}
		player.pitch = updateAndStepTween(&data.pitchTween).(f32)
		player3DApplyCameraRotation(player)

		if tweenIsFinished(data.yawTween) && tweenIsFinished(data.pitchTween) {
			if data.horizontalState == .Forward &&
			   data.verticalState == .Middle &&
			   rl.IsKeyPressed(.LEFT_SHIFT) {
				movePlayer3D(player, global.camera3D.position, PLAYER_3D_PANEL_POSITION, .Panel)
			}
		}
	case .Moving:
		global.camera3D.position =
		updateAndStepTween(&player.movingStateData.movementTween).(rl.Vector3)
		global.camera3D.target = global.camera3D.position + player.movingStateData.look
		if tweenIsFinished(player.movingStateData.movementTween) {
			setPlayer3DState(player, player.movingStateData.nextState)
		}
		player3DApplyCameraRotation(player)
	case .Panel:
		if rl.IsKeyPressed(.DOWN) {
			movePlayer3D(player, global.camera3D.position, PLAYER_3D_INSIDE_POSITION, .Looking)
			break
		}
		if !rl.IsMouseButtonPressed(.LEFT) {
			break
		}
		panelMesh := global.elevator3D.mainModel.meshes[Elevator3DModelMeshes.Panel]
		panelBbox := rl.GetMeshBoundingBox(panelMesh)
		ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), global.camera3D)
		rayCollision := rl.GetRayCollisionBox(ray, panelBbox)
		if rayCollision.hit {
			panelScreenRectStart := rl.GetWorldToScreen(panelBbox.min, global.camera3D)
			panelScreenRectEnd := rl.GetWorldToScreen(panelBbox.max, global.camera3D)
			panelScreenRectSize := panelScreenRectEnd - panelScreenRectStart
			screenPosition := rl.GetWorldToScreen(rayCollision.point, global.camera3D)
			panelPositionNormalized :=
				(screenPosition - panelScreenRectStart) / panelScreenRectSize
			panelPositionNormalized.y = 1.0 - panelPositionNormalized.y
			panelPosition :=
				panelPositionNormalized *
				getTextureSize(global.elevator3D.panelRenderTexture.texture)
			elevatorPanel3DInput(&global.elevator3D.panelData, panelPosition)
		} else {
			fmt.println("No collision")
		}
	}
}
movePlayer3D :: proc(
	player: ^Player3D,
	from: rl.Vector3,
	to: rl.Vector3,
	nextState: Player3DState,
	duration: f32 = 1.0,
) {
	assert(nextState != .Moving && nextState != .Uninitialized)
	if nextState == player.state {
		return
	}
	player.movingStateData = {
		movementTween = createTween(TweenVector3Range{from, to}, .InvExp, duration),
		look          = global.camera3D.target - global.camera3D.position,
		nextState     = nextState,
	}
	setPlayer3DState(player, .Moving)
}

Elevator3DModelMeshes :: enum {
	Walls,
	Floor,
	Ceiling,
	PanelBox,
	Panel,
}
ELEVATOR_3D_PANEL_RENDER_TEXTURE_WIDTH :: 180
ElevatorPanelData :: struct {
	buttonState:      [ELEVATOR_PANEL_BUTTON_COUNT.x][ELEVATOR_PANEL_BUTTON_COUNT.y]i32,
	buttonSeparation: rl.Vector2,
	buttonArea:       rl.Rectangle,
	knobState:        [2]f32,
	knobSeparation:   rl.Vector2,
	knobArea:         rl.Rectangle,
	sliderState:      [3]f32,
	sliderSeparation: rl.Vector2,
	sliderArea:       rl.Rectangle,
}
elevatorPanel3DInput :: proc(panel: ^ElevatorPanelData, position: rl.Vector2) {
	if pointInRec(position, panel.buttonArea) {
		relativeButtonPosition :=
			(position - {panel.buttonArea.x, panel.buttonArea.y}) / panel.buttonSeparation
		relativeButtonPositionFloored := rl.Vector2 {
			math.floor(relativeButtonPosition.x),
			math.floor(relativeButtonPosition.y),
		}
		buttonSpriteDef := getSpriteDef(.ElevatorPanelButton)
		buttonTextureSize := f32(buttonSpriteDef.frame_width)
		buttonPosition :=
			relativeButtonPositionFloored * panel.buttonSeparation +
			buttonTextureSize / 2.0 +
			{panel.buttonArea.x, panel.buttonArea.y}
		buttonRadius := buttonTextureSize / 2.0
		if pointInCircle(position, buttonPosition, buttonRadius) {
			relativeButtonIndex := iVector2 {
				i32(relativeButtonPositionFloored.x),
				i32(relativeButtonPositionFloored.y),
			}
			rl.PlaySound(getSound(.ElevatorPanelButton))
			if panel.buttonState[relativeButtonIndex.x][relativeButtonIndex.y] == 1 {
				panel.buttonState[relativeButtonIndex.x][relativeButtonIndex.y] = 0
			} else {
				panel.buttonState[relativeButtonIndex.x][relativeButtonIndex.y] = 1
			}
		}
	} else if pointInRec(position, panel.knobArea) {
		knobAreaPosition := rl.Vector2{panel.knobArea.x, panel.knobArea.y}
		relativeKnobPosition := rl.Vector2 {
			0.0,
			(position.y - knobAreaPosition.y) / panel.knobSeparation.y,
		}
		relativeKnobPositionFloored := rl.Vector2 {
			math.floor(relativeKnobPosition.x),
			math.floor(relativeKnobPosition.y),
		}
		knobTexture := getTexture(.ElevatorPanelKnob)
		knobTextureSize := getTextureSize(knobTexture)
		knobPosition :=
			knobAreaPosition +
			relativeKnobPositionFloored * panel.knobSeparation +
			knobTextureSize / 2.0
		knobRadius := knobTextureSize.x / 2.0
		if pointInCircle(position, knobPosition, knobRadius) {
			knobIndex := int(relativeKnobPositionFloored.y)
			panel.knobState[knobIndex] += 45.0
			knobSounds := [?]rl.Sound {
				getSound(.ElevatorPanelKnob1),
				getSound(.ElevatorPanelKnob2),
				getSound(.ElevatorPanelKnob3),
			}
			rl.PlaySound(rand.choice(knobSounds[:]))
		}
	} else if pointInRec(position, panel.sliderArea) {
		sliderAreaStart := rl.Vector2{panel.sliderArea.x, panel.sliderArea.y}
		relativePosition := position - sliderAreaStart
		sliderIndex := i32(math.floor(relativePosition.x / panel.sliderSeparation.x))
		panel.sliderState[sliderIndex] = rand.float32() * panel.sliderArea.height
		rl.PlaySound(getSound(.ElevatorPanelSlider))
	}
}
ELEVATOR_PANEL_BUTTON_COUNT: iVector2 : {3, 8}
Elevator3D :: struct {
	mainModel:          rl.Model,
	leftDoorModel:      rl.Model,
	rightDoorModel:     rl.Model,
	wallMaterial:       rl.Material,
	lightMaterial:      rl.Material,
	floorMaterial:      rl.Material,
	insideElevatorPos:  rl.Vector3,
	panelRenderTexture: rl.RenderTexture,
	panelMaterial:      rl.Material,
	panelData:          ElevatorPanelData,
	lightFrameIndex:    f32,
}
createElevator3D :: proc() -> Elevator3D {
	lightMaterial := rl.LoadMaterialDefault()
	lightMaterial.shader = getShader(.AnimatedTexture3D)
	rl.SetMaterialTexture(&lightMaterial, .ALBEDO, getTexture(.ElevatorLights3D))

	panelMesh := getModel(.Elevator).meshes[Elevator3DModelMeshes.Panel]
	panelMeshBbox := rl.GetMeshBoundingBox(panelMesh)
	panelMeshSize := panelMeshBbox.max.yz - panelMeshBbox.min.yz
	panelMeshRatio := panelMeshSize.x / panelMeshSize.y
	panelRenderTextureHeight := i32(f32(ELEVATOR_3D_PANEL_RENDER_TEXTURE_WIDTH) * panelMeshRatio)
	panelRenderTexture := rl.LoadRenderTexture(
		ELEVATOR_3D_PANEL_RENDER_TEXTURE_WIDTH,
		panelRenderTextureHeight,
	)
	return Elevator3D {
		mainModel = getModel(.Elevator),
		leftDoorModel = getModel(.ElevatorSlidingDoorLeft),
		rightDoorModel = getModel(.ElevatorSlidingDoorRight),
		wallMaterial = loadPassthroughMaterial3D(getTexture(.ElevatorWall3D)),
		lightMaterial = lightMaterial,
		floorMaterial = loadPassthroughMaterial3D(),
		panelMaterial = loadPassthroughMaterial3D(panelRenderTexture.texture),
		panelRenderTexture = panelRenderTexture,
		panelData = {
			buttonArea = {
				21.0,
				90.0,
				24.0 * f32(ELEVATOR_PANEL_BUTTON_COUNT.x),
				24.0 * f32(ELEVATOR_PANEL_BUTTON_COUNT.y),
			},
			buttonSeparation = {24.0, 24.0},
			knobArea = {110.0, 90.0, 44.0, 44.0 * 2},
			knobSeparation = {0.0, 44.0},
			sliderArea = {101.0, 197.0, 24.0 * 3.0, 80.0},
			sliderSeparation = {24.0, 0.0},
		},
		lightFrameIndex = 1.0,
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
drawElevator3D :: proc(e: ^Elevator3D) {
	g := global
	renderElevator3DPanelTexture(e.panelRenderTexture, &e.panelData)
	transform := rl.MatrixIdentity()
	applyLightToShader(e.wallMaterial.shader)
	rl.DrawMesh(e.mainModel.meshes[Elevator3DModelMeshes.Walls], e.wallMaterial, transform)

	applyLightToShader(e.floorMaterial.shader)
	setShaderValue(e.lightMaterial.shader, "frameIndex", &e.lightFrameIndex)
	lightFrameCount: int = 2
	setShaderValue(e.lightMaterial.shader, "frameCount", &lightFrameCount)
	lightFlipY: int = 0
	setShaderValue(e.lightMaterial.shader, "flipY", &lightFlipY)
	rl.DrawMesh(e.mainModel.meshes[Elevator3DModelMeshes.Floor], e.floorMaterial, transform)

	applyLightToShader(e.lightMaterial.shader)
	rl.DrawMesh(e.mainModel.meshes[Elevator3DModelMeshes.Ceiling], e.lightMaterial, transform)

	applyLightToShader(global.defaultMaterial3D.shader)
	rl.DrawMesh(
		e.mainModel.meshes[Elevator3DModelMeshes.PanelBox],
		global.defaultMaterial3D,
		transform,
	)

	applyLightToShader(e.panelMaterial.shader)
	panelFrameIndex: f32 = 0.0
	setShaderValue(e.panelMaterial.shader, "frameIndex", &e.lightFrameIndex)
	panelFrameCount: int = 1
	setShaderValue(e.panelMaterial.shader, "frameCount", &panelFrameCount)
	panelFlipY: int = 1
	setShaderValue(e.panelMaterial.shader, "flipY", &panelFlipY)
	rl.DrawMesh(e.mainModel.meshes[Elevator3DModelMeshes.Panel], e.panelMaterial, transform)

	rl.DrawMesh(e.leftDoorModel.meshes[0], global.defaultMaterial3D, e.leftDoorModel.transform)
	rl.DrawMesh(e.rightDoorModel.meshes[0], global.defaultMaterial3D, e.rightDoorModel.transform)
}
renderElevator3DPanelTexture :: proc(renderTexture: rl.RenderTexture, data: ^ElevatorPanelData) {
	rl.EndMode3D()
	beginNestedTextureMode(renderTexture)
	rl.ClearBackground({0, 0, 0, 0})

	buttonSprite := createSprite(getSpriteDef(.ElevatorPanelButton))
	for x in 0 ..< ELEVATOR_PANEL_BUTTON_COUNT.x {
		for y in 0 ..< ELEVATOR_PANEL_BUTTON_COUNT.y {
			pos :=
				rl.Vector2{f32(x), f32(y)} * data.buttonSeparation +
				{data.buttonArea.x, data.buttonArea.y}
			setSpriteFrame(&buttonSprite, data.buttonState[x][y])
			drawSpriteEx(buttonSprite, pos, {1.0, 1.0})
		}
	}

	knobTexture := getTexture(.ElevatorPanelKnob)
	knobTextureSize := getTextureSize(knobTexture)
	knobTextureOrigin := knobTextureSize / 2.0
	knobTextureSource := getTextureRec(knobTexture)
	knobFirstPosition := rl.Vector2{data.knobArea.x, data.knobArea.y}
	rl.DrawTexturePro(
		knobTexture,
		knobTextureSource,
		getTextureDestinationRectangle(knobTexture, knobFirstPosition + knobTextureOrigin),
		knobTextureOrigin,
		data.knobState[0],
		rl.WHITE,
	)
	rl.DrawTexturePro(
		knobTexture,
		knobTextureSource,
		getTextureDestinationRectangle(
			knobTexture,
			knobFirstPosition + data.knobSeparation + knobTextureOrigin,
		),
		knobTextureOrigin,
		data.knobState[1],
		rl.WHITE,
	)

	sliderTexture := getTexture(.ElevatorPanelSlider)
	sliderTextureSize := getTextureSize(sliderTexture)
	sliderTextureOrigin := sliderTextureSize / 2.0
	sliderAreaPosition := rl.Vector2{data.sliderArea.x, data.sliderArea.y}
	for i in 0 ..< 3 {
		sliderRidgeWidth: f32 = 3.0
		sliderRidgeStart :=
			sliderAreaPosition + f32(i) * data.sliderSeparation + sliderTextureOrigin
		sliderRidgeStart.x -= math.floor(sliderRidgeWidth / 2.0)
		sliderRidgeEnd := sliderRidgeStart + {sliderRidgeWidth, data.sliderArea.height}
		sliderRidgeSize := sliderRidgeEnd - sliderRidgeStart
		sliderRidgeRectangle := rl.Rectangle {
			sliderRidgeStart.x,
			sliderRidgeStart.y,
			sliderRidgeSize.x,
			sliderRidgeSize.y,
		}
		rl.DrawRectangleRec(sliderRidgeRectangle, rl.BLACK)
	}
	for i in 0 ..< 3 {
		sliderPosition :=
			sliderAreaPosition + f32(i) * data.sliderSeparation + {0.0, data.sliderState[i]}
		rl.DrawTextureV(sliderTexture, sliderPosition, rl.WHITE)
	}

	endNestedTextureMode()
	rl.BeginMode3D(global.camera3D)
}
destroyElevator3D :: proc(e: ^Elevator3D) {
	unloadMaterialMapOnly(e.wallMaterial)
	unloadMaterialMapOnly(e.lightMaterial)
	unloadMaterialMapOnly(e.floorMaterial)
	unloadMaterialMapOnly(e.panelMaterial)
	rl.UnloadRenderTexture(e.panelRenderTexture)
}
