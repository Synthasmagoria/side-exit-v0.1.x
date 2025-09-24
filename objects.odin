package game
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:math/rand"
import "core:mem"
import "core:reflect"
import "core:strings"
import rl "lib/raylib"
import rlgl "lib/raylib/rlgl"

Player :: struct {
	object:         ^GameObject,
	idleSpr:        Sprite,
	walkSpr:        Sprite,
	currentSpr:     ^Sprite,
	scale:          rl.Vector2,
	colRec:         rl.Rectangle,
	velocity:       rl.Vector2,
	maxVelocity:    rl.Vector2,
	frozen:         i32,
	walkSpd:        f32,
	verticalGrav:   f32,
	verticalDampen: f32,
	jumpStr:        f32,
	airjumpStr:     f32,
	airjumpCount:   i32,
	airjumpIndex:   i32,
}
createPlayer :: proc(alloc: mem.Allocator) -> ^Player {
	self := new(Player, alloc)
	self.idleSpr = createSprite(getSpriteDef(.SynthIdle))
	self.walkSpr = createSprite(getSpriteDef(.SynthWalk))
	self.currentSpr = &self.idleSpr
	self.maxVelocity = {6.5, 6.5}
	self.jumpStr = 7.0
	self.walkSpd = 2.0
	self.verticalGrav = 0.5
	self.verticalDampen = 0.7
	self.scale = {1.0, 1.0}
	self.airjumpStr = 5.8
	self.airjumpCount = 1
	self.airjumpIndex = 0
	self.object = createGameObject(
		Player,
		self,
		-100,
		updateProc = cast(proc(_: rawptr))updatePlayer,
		drawProc = cast(proc(_: rawptr))drawPlayer,
	)
	self.object.pos = {0.0, 0.0}
	self.object.colRec = {7.0, 3.0, 12.0, 20.0}
	return self
}
updatePlayer :: proc(self: ^Player) {
	rightInput := rl.IsKeyDown(.RIGHT)
	leftInput := rl.IsKeyDown(.LEFT)
	walkInput := f32(int(rightInput)) - f32(int(leftInput))

	onFloor :=
		doSolidCollision(getObjectAbsoluteCollisionRectangle(self.object, {0.0, 1.0})) != nil &&
		self.velocity.y >= 0.0
	if onFloor {
		self.airjumpIndex = 0
	} else {
		self.velocity.y += self.verticalGrav
	}

	self.velocity.x = walkInput * self.walkSpd * f32(self.frozen ~ 1)
	if 0.0 < math.abs(self.velocity.x) {
		self.scale.x = math.abs(self.scale.x) * math.sign(self.velocity.x)
	}
	jumpInput := rl.IsKeyPressed(.SPACE)
	if jumpInput {
		if onFloor {
			self.velocity.y = -self.jumpStr
			onFloor = false
			rl.PlaySound(getSound(.PlayerJump))
		} else if self.airjumpIndex < self.airjumpCount {
			self.velocity.y = -self.airjumpStr
			self.airjumpIndex += 1
			rl.PlaySound(getSound(.PlayerAirJump))
		}
	}
	if !onFloor && self.velocity.y < 0.0 && rl.IsKeyReleased(.SPACE) {
		self.velocity.y *= self.verticalDampen
	}

	self.velocity = rl.Vector2Clamp(self.velocity, -self.maxVelocity, self.maxVelocity)

	moveAndCollideResult := moveAndCollidePlayer(
		self.object.pos,
		self.object.colRec,
		self.velocity,
		math.sign(self.scale.x),
	)
	self.object.pos = moveAndCollideResult.newPosition
	self.velocity = moveAndCollideResult.newVelocity
}
drawPlayer :: proc(self: ^Player) {
	if math.abs(self.velocity.x) > 0.0 {
		if self.frozen == 0 {
			setPlayerSprite(self, &self.walkSpr)
		}
	} else {
		setPlayerSprite(self, &self.idleSpr)
	}
	drawSpriteEx(self.currentSpr^, self.object.pos, self.scale)
	if self.frozen == 0 {
		updateSprite(self.currentSpr)
	}
}
MoveAndCollidePlayerResult :: struct {
	newPosition: rl.Vector2,
	newVelocity: rl.Vector2,
}
moveAndCollidePlayer :: proc(
	position: rl.Vector2,
	collisionRectangle: rl.Rectangle,
	velocity: rl.Vector2,
	facing: f32,
) -> MoveAndCollidePlayerResult {
	result := MoveAndCollidePlayerResult {
		newPosition = position,
		newVelocity = velocity,
	}
	collisionRectangleI32 := iRectangle {
		i32(collisionRectangle.x),
		i32(collisionRectangle.y),
		i32(collisionRectangle.width),
		i32(collisionRectangle.height),
	}
	absoluteHitboxDiagonal := shiftRectangle(
		collisionRectangle,
		result.newPosition + result.newVelocity,
	)
	if collisionRectangleDiagonal := doSolidCollision(absoluteHitboxDiagonal);
	   collisionRectangleDiagonal != nil {
		absoluteHitboxVertical := shiftRectangle(
			collisionRectangle,
			result.newPosition + {0.0, result.newVelocity.y},
		)
		if collisionRectangleVertical := doSolidCollision(absoluteHitboxVertical);
		   collisionRectangleVertical != nil {
			verticalDirection := math.sign(result.newVelocity.y)
			if (verticalDirection == 1.0) {
				result.newPosition.y = f32(
					collisionRectangleVertical.?.y -
					collisionRectangleI32.y -
					collisionRectangleI32.height -
					1.0,
				)
			} else {
				result.newPosition.y = f32(
					collisionRectangleVertical.?.y +
					collisionRectangleVertical.?.height -
					collisionRectangleI32.y +
					1.0,
				)
			}
			result.newVelocity.y = 0.0
		} else {
			result.newPosition.y += result.newVelocity.y
		}

		absoluteHitboxHorizontal := shiftRectangle(
			collisionRectangle,
			result.newPosition + {result.newVelocity.x, 0.0},
		)
		if collisionRectangleHorizontal := doSolidCollision(absoluteHitboxHorizontal);
		   collisionRectangleHorizontal != nil {
			if (facing == 1.0) {
				result.newPosition.x = f32(
					collisionRectangleHorizontal.?.x -
					collisionRectangleI32.x -
					collisionRectangleI32.width -
					1.0,
				)
			} else {
				result.newPosition.x = f32(
					collisionRectangleHorizontal.?.x +
					collisionRectangleHorizontal.?.width -
					collisionRectangleI32.x +
					1.0,
				)
			}
		} else {
			result.newPosition.x += result.newVelocity.x
		}
	} else {
		result.newPosition += result.newVelocity
	}
	return result
}
setPlayerSprite :: proc(player: ^Player, spr: ^Sprite) {
	if (player.currentSpr != spr) {
		player.currentSpr = spr
		setSpriteFrame(player.currentSpr, 0)
	}
}

ElevatorState :: enum {
	Gone,
	Arriving,
	Interactable,
	PlayerInside,
	Leaving,
}
ElevatorArrivingStateData :: struct {
	movementTween: Tween,
	alphaTween:    Tween,
}
ElevatorLeavingStateData :: struct {
	movementTween: Tween,
	alphaTween:    Tween,
}
Elevator :: struct {
	visible:              bool,
	instant:              bool,
	interactionArrowSpr:  Sprite,
	drawOffset:           rl.Vector2,
	object:               ^GameObject,
	state:                ElevatorState,
	arrivingStateData:    ElevatorArrivingStateData,
	leavingStateData:     ElevatorLeavingStateData,
	drawInteractionArrow: bool,
	blend:                rl.Color,
	panelBlend:           rl.Color,
	activationDist:       f32,
}
createElevator :: proc(alloc: mem.Allocator) -> ^Elevator {
	self := new(Elevator, alloc)
	self.interactionArrowSpr = createSprite(getSpriteDef(.InteractionIndicationArrow))
	self.state = .Gone
	self.drawOffset = {0.0, -224.0}
	self.blend = {255, 255, 255, 0}
	self.panelBlend = rl.WHITE
	self.activationDist = 128.0
	self.object = createGameObject(
		Elevator,
		self,
		0,
		updateProc = cast(proc(_: rawptr))updateElevator,
		drawProc = cast(proc(_: rawptr))drawElevator,
		drawEndProc = cast(proc(_: rawptr))drawElevatorEnd,
	)
	setElevatorState(self, .Gone)
	self.object.pos = {0.0, 0.0}
	self.object.colRec = getTextureRec(getTexture(.Elevator))
	return self
}
updateElevator :: proc(self: ^Elevator) {
	switch (self.state) {
	case .Gone:
		if player := getFirstGameObjectOfType(Player); player != nil {
			if linalg.distance(player.object.pos, self.object.pos) < self.activationDist {
				setElevatorState(self, .Arriving)
			}
		}
	case .Arriving:
		self.drawOffset = updateAndStepTween(&self.arrivingStateData.movementTween).(rl.Vector2)
		self.blend.a = updateAndStepTween(&self.arrivingStateData.alphaTween).(u8)
		if tweenIsFinished(self.arrivingStateData.movementTween) &&
		   tweenIsFinished(self.arrivingStateData.alphaTween) {
			setElevatorState(self, .Interactable)
		}
	case .Interactable:
		if player := getFirstGameObjectOfType(Player); player != nil {
			if linalg.distance(player.object.pos, self.object.pos) >= self.activationDist {
				setElevatorState(self, .Leaving)
				break
			} else {
				if pointInRectangle(
					getObjectCenterAbsolute(player.object^),
					getObjectAbsoluteCollisionRectangle(self.object, {0.0, 0.0}),
				) {
					self.drawInteractionArrow = true
					if rl.IsKeyPressed(.UP) {
						player.frozen = 1
						setElevatorState(self, .PlayerInside)
						break
					}
				} else {
					self.drawInteractionArrow = false
				}
			}
		}
	case .PlayerInside:

	case .Leaving:
		self.drawOffset = updateAndStepTween(&self.leavingStateData.movementTween).(rl.Vector2)
		self.blend.a = updateAndStepTween(&self.leavingStateData.alphaTween).(u8)
		if tweenIsFinished(self.leavingStateData.alphaTween) &&
		   tweenIsFinished(self.leavingStateData.alphaTween) {
			setElevatorState(self, .Gone)
		}
	}
}
drawElevator :: proc(self: ^Elevator) {
	if self.visible {
		rl.DrawTextureV(getTexture(.Elevator), self.object.pos + self.drawOffset, self.blend)
	}
}
drawElevatorEnd :: proc(self: ^Elevator) {
	if self.drawInteractionArrow {
		if player := getFirstGameObjectOfType(Player); player != nil {
			abovePlayerCenter :=
				getObjectCenterAbsolute(player.object^) - {0.0, player.object.colRec.height}
			drawSpriteEx(self.interactionArrowSpr, abovePlayerCenter, {1.0, 1.0})
			updateSprite(&self.interactionArrowSpr)
		}
	}
}
setElevatorState :: proc(self: ^Elevator, newState: ElevatorState) {
	if (self.state == newState) {
		return
	}
	#partial switch (self.state) {
	case .Interactable:
		self.drawInteractionArrow = false
	case .Arriving:
	//rl.PlaySound(getSound(.ElevatorArrive))
	}
	self.state = newState
	switch self.state {
	case .Gone:
		self.blend = {255, 255, 255, 0}
	case .Arriving:
		if self.instant {
			self.drawOffset = {0.0, 0.0}
			self.blend.a = 255
			setElevatorState(self, .Interactable)
		} else {
			self.blend = {255, 255, 255, 0}
			self.arrivingStateData.movementTween = createTween(
				TweenVector2Range{{0.0, -224.0}, {0.0, 0.0}},
				.InvExp,
				2.0,
			)
			self.arrivingStateData.alphaTween = createTween(TweenU8Range{0, 255}, .Linear, 0.7)
		}
	case .Interactable:
	case .PlayerInside:
		if player := getFirstGameObjectOfType(Player); player != nil {
			player.frozen = 1
		}
		movePlayer3D(
			&global.player3D,
			PLAYER_3D_OUTSIDE_POSITION,
			PLAYER_3D_INSIDE_POSITION,
			.Looking,
		)
	case .Leaving:
		self.blend = rl.WHITE
		self.leavingStateData.movementTween = createTween(
			TweenVector2Range{{0.0, 0.0}, {0.0, -224.0}},
			.Exp,
			2.0,
		)
		self.leavingStateData.alphaTween = createTween(TweenU8Range{255, 0}, .Linear, 0.7, 1.3)
	}
}

TITLE_MENU_TEXT_SIZE_BIG :: 32
TITLE_MENU_TEXT_SIZE_SMALL :: 16
TitleMenu :: struct {
	object:      ^GameObject,
	options:     [2]string,
	optionIndex: i32,
}
createTitleMenu :: proc(levelAlloc: mem.Allocator) -> ^TitleMenu {
	self := new(TitleMenu, levelAlloc)
	self.options = [2]string{"Start", "Quit"}
	self.optionIndex = 0
	self.object = createGameObject(
		TitleMenu,
		self,
		0,
		updateProc = cast(proc(_: rawptr))updateTitleMenu,
		drawProc = cast(proc(_: rawptr))drawTitleMenu,
	)
	self.object.pos = {
		RENDER_TEXTURE_WIDTH_2D / 2,
		RENDER_TEXTURE_HEIGHT_2D / 2 + RENDER_TEXTURE_HEIGHT_2D / 4,
	}
	return self
}
updateTitleMenu :: proc(self: ^TitleMenu) {
	// TODO: Play menu select sound
	if rl.IsKeyPressed(.DOWN) {
		self.optionIndex = (self.optionIndex + 1) % i32(len(self.options))
	} else if rl.IsKeyPressed(.UP) {
		self.optionIndex = wrapi(self.optionIndex - 1, 0, i32(len(self.options)))
	}
	if rl.IsKeyPressed(.ENTER) {
		switch self.optionIndex {
		case 0:
			loadLevel(.Hub)
		case 1:
			global.windowCloseRequest = true
		}
	}
}
drawTitleMenu :: proc(self: ^TitleMenu) {
	font := rl.GetFontDefault()
	for i in 0 ..< len(self.options) {
		if i32(i) != self.optionIndex {
			drawTextAligned(
				strings.clone_to_cstring(self.options[i]),
				self.object.pos + {0.0, f32(i) * TITLE_MENU_TEXT_SIZE_BIG},
				font,
				TITLE_MENU_TEXT_SIZE_SMALL,
				rl.WHITE,
				.Center,
				.Middle,
			)
		}
	}
	drawTextAligned(
		strings.clone_to_cstring(self.options[self.optionIndex]),
		self.object.pos + {0.0, f32(self.optionIndex) * TITLE_MENU_TEXT_SIZE_BIG},
		font,
		TITLE_MENU_TEXT_SIZE_BIG,
		rl.WHITE,
		.Center,
		.Middle,
	)
}

TitleMenuBackground :: struct {
	object:               ^GameObject,
	elevatorAngle:        f32,
	backgroundShaderTime: f32,
}
createTitleMenuBackground :: proc(levelAlloc: mem.Allocator) -> ^TitleMenuBackground {
	self := new(TitleMenuBackground, levelAlloc)
	self.object = createGameObject(
		TitleMenuBackground,
		self,
		0,
		updateProc = cast(proc(_: rawptr))updateTitleMenuBackground,
		drawProc = cast(proc(_: rawptr))drawTitleMenuBackground,
		draw3DProc = cast(proc(_: rawptr))drawTitleMenuBackground3D,
	)
	self.elevatorAngle = 0.0
	return self
}
updateTitleMenuBackground :: proc(self: ^TitleMenuBackground) {
	self.elevatorAngle += TARGET_TIME_STEP * 30.0
	self.backgroundShaderTime += TARGET_TIME_STEP
}
drawTitleMenuBackground :: proc(self: ^TitleMenuBackground) {
	backgroundShaderTexture := getTexture(.White32)
	backgroundShaderSource := getTextureRec(backgroundShaderTexture)
	backgroundShaderDest := rl.Rectangle {
		0.0,
		0.0,
		RENDER_TEXTURE_WIDTH_2D,
		RENDER_TEXTURE_HEIGHT_2D,
	}
	backgroundShader := getShader(.TitleMenuFog)
	rl.BeginShaderMode(backgroundShader)
	setShaderValue(backgroundShader, "time", &self.backgroundShaderTime)
	rl.DrawTexturePro(
		backgroundShaderTexture,
		backgroundShaderSource,
		backgroundShaderDest,
		{0.0, 0.0},
		0.0,
		{255, 255, 255, 192},
	)
	rl.EndShaderMode()
}
drawTitleMenuBackground3D :: proc(self: ^TitleMenuBackground) {
	rlgl.DisableBackfaceCulling()
	rl.DrawModelWiresEx(
		getModel(.ElevatorTitleMenu),
		FORWARD_3D * 25.0 + RIGHT_3D * 16.0,
		{0.1, 1.0, 0.0},
		self.elevatorAngle,
		{1.0, 1.0, 1.0},
		rl.WHITE,
	)
	rlgl.EnableBackfaceCulling()
}

StarBackground :: struct {
	genTex:     rl.Texture,
	frameSize:  rl.Vector2,
	frameIndex: f32,
	frameSpd:   f32,
	frameCount: i32,
	scroll:     rl.Vector2,
	scrollSpd:  rl.Vector2,
	object:     ^GameObject,
}
createStarBackground :: proc(levelAlloc: mem.Allocator) -> ^StarBackground {
	self := new(StarBackground, levelAlloc)
	self.genTex = web10CreateTexture({128, 128}, getSpriteDef(.Star), 16)
	self.frameSize = {128.0, 128.0}
	self.frameSpd = 4.0
	self.frameCount = getSpriteDef(.Star).frame_count
	self.scrollSpd = rl.Vector2{30.0, 30.0}
	self.object = createGameObject(
		StarBackground,
		self,
		0,
		updateProc = cast(proc(_: rawptr))updateStarBackground,
		drawProc = cast(proc(_: rawptr))drawStarBackground,
		destroyProc = cast(proc(_: rawptr))destroyStarBackground,
	)
	return self
}
updateStarBackground :: proc(self: ^StarBackground) {
	self.object.pos = global.camera.target - global.camera.offset
}
drawStarBackground :: proc(self: ^StarBackground) {
	shd := getShader(.AnimatedTextureRepeatPosition)
	rl.BeginShaderMode(shd)
	frameCountLoc := rl.GetShaderLocation(shd, "frameCount")
	rl.SetShaderValue(shd, frameCountLoc, &self.frameCount, .INT)
	frameIndexLoc := rl.GetShaderLocation(shd, "frameInd")
	rl.SetShaderValue(shd, frameIndexLoc, &self.frameIndex, .FLOAT)
	texSizeLoc := rl.GetShaderLocation(shd, "frameSize")
	rl.SetShaderValue(shd, texSizeLoc, &self.frameSize, .VEC2)
	self.frameIndex += TARGET_TIME_STEP * self.frameSpd
	scrollPxLoc := rl.GetShaderLocation(shd, "scrollPx")
	rl.SetShaderValue(shd, scrollPxLoc, &self.scroll, .VEC2)
	self.scroll += self.scrollSpd * TARGET_TIME_STEP
	drawTextureRecDest(
		self.genTex,
		{self.object.pos.x, self.object.pos.y, RENDER_TEXTURE_WIDTH_2D, RENDER_TEXTURE_HEIGHT_2D},
	)
	rl.EndShaderMode()
}
destroyStarBackground :: proc(self: ^StarBackground) {
	rl.UnloadTexture(self.genTex)
}

HubGraphics :: struct {
	object:                      ^GameObject,
	postProcessingRenderTexture: rl.RenderTexture,
	shaderTime:                  f32,
}
createHubGraphics :: proc(levelAlloc: mem.Allocator) -> ^HubGraphics {
	self := new(HubGraphics, levelAlloc)
	self.object = createGameObject(
		HubGraphics,
		self,
		0,
		drawProc = cast(proc(_: rawptr))drawHubGraphics,
		drawEndProc = cast(proc(_: rawptr))drawHubGraphicsEnd,
		destroyProc = cast(proc(_: rawptr))destroyHubGraphics,
	)
	self.postProcessingRenderTexture = rl.LoadRenderTexture(
		RENDER_TEXTURE_WIDTH_2D,
		RENDER_TEXTURE_HEIGHT_2D,
	)
	return self
}
destroyHubGraphics :: proc(self: ^HubGraphics) {
	rl.UnloadRenderTexture(self.postProcessingRenderTexture)
}
drawHubGraphics :: proc(self: ^HubGraphics) {
	rl.DrawTextureV(getTexture(.HubBackground), {0.0, 0.0}, rl.WHITE)
	rl.DrawTextureV(getTexture(.HubBuilding), {0.0, 0.0}, rl.WHITE)
}
drawHubGraphicsEnd :: proc(self: ^HubGraphics) {
	// TODO: This shit could be done a lot more optimally
	beginModeStacked(getZeroCamera2D(), self.postProcessingRenderTexture)
	shader := getShader(.NoiseAndCRT)
	rl.BeginShaderMode(shader)
	self.shaderTime += TARGET_TIME_STEP
	setShaderValue(shader, "time", &self.shaderTime)
	noiseFactor: f32 = 0.3
	setShaderValue(shader, "noiseFactor", &noiseFactor)
	crtWidth: f32 = 96.0
	setShaderValue(shader, "crtWidth", &crtWidth)
	crtFactor: f32 = 0.3
	setShaderValue(shader, "crtFactor", &crtFactor)
	crtSpeed: f32 = 40.0
	setShaderValue(shader, "crtSpeed", &crtSpeed)
	rl.DrawTexture(engine.renderTexture2D.texture, 0, 0, rl.WHITE)
	rl.EndShaderMode()
	endModeStacked()
	worldPosition := global.camera.target - global.camera.offset
	rl.DrawTextureV(self.postProcessingRenderTexture.texture, worldPosition, rl.WHITE)
}

UnrulyLandGraphics :: struct {
	object:             ^GameObject,
	blockRenderTexture: rl.RenderTexture,
}
createUnrulyLandGraphics :: proc(levelAlloc: mem.Allocator) -> ^UnrulyLandGraphics {
	self := new(UnrulyLandGraphics, levelAlloc)
	self.blockRenderTexture = rl.LoadRenderTexture(
		RENDER_TEXTURE_WIDTH_2D,
		RENDER_TEXTURE_HEIGHT_2D,
	)
	self.object = createGameObject(
		UnrulyLandGraphics,
		self,
		100,
		drawProc = cast(proc(_: rawptr))drawUnrulyLandGraphics,
		destroyProc = cast(proc(_: rawptr))destroyUnrulyLandGraphics,
	)
	return self
}
drawUnrulyLandGraphics :: proc(self: ^UnrulyLandGraphics) {
	beginModeStacked(nil, self.blockRenderTexture)
	rl.ClearBackground({0, 0, 0, 0})
	for rectangle in engine.collisionRectangles {
		rectangleF32 := rl.Rectangle {
			f32(rectangle.x),
			f32(rectangle.y),
			f32(rectangle.width),
			f32(rectangle.height),
		}
		rl.DrawRectangleRec(rectangleF32, rl.WHITE)
	}
	endModeStacked()
	outlineShader := getShader(.InsetOutline)
	rl.BeginShaderMode(outlineShader)
	outlineThickness: f32 = 2.0
	setShaderValue(outlineShader, "outlineThickness", &outlineThickness)
	renderTextureSize := getTextureSize(self.blockRenderTexture.texture)
	outlineShaderTexelSize := rl.Vector2{1.0, 1.0} / renderTextureSize
	setShaderValue(outlineShader, "texelSize", &outlineShaderTexelSize)
	outlineShaderFlipY: i32 = 1
	setShaderValue(outlineShader, "flipY", &outlineShaderFlipY)
	rl.DrawTextureV(
		self.blockRenderTexture.texture,
		global.camera.target - global.camera.offset,
		rl.WHITE,
	)
	rl.EndShaderMode()
}
destroyUnrulyLandGraphics :: proc(self: ^UnrulyLandGraphics) {
	rl.UnloadRenderTexture(self.blockRenderTexture)
}

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
	self := Player3D {
		lookingStateData = {
			yawTween = createFinishedTween(0.0),
			pitchTween = createFinishedTween(0.0),
			horizontalState = .Forward,
			verticalState = .Middle,
		},
	}
	setPlayer3DState(&self, .Inactive)
	return self
}
setPlayer3DState :: proc(player: ^Player3D, nextState: Player3DState) {
	if player.state == nextState {
		return
	}
	previousState := player.state
	player.state = nextState
	switch player.state {
	case .Uninitialized:
	case .Inactive:
		global.camera3D.position = PLAYER_3D_OUTSIDE_POSITION
		player3DApplyCameraRotation(player)
		if previousState != .Uninitialized {
			if player := getFirstGameObjectOfType(Player); player != nil {
				player.frozen = 0
			} else {
				panic("Couldn't make player frozen because there was no player")
			}
			if elevator := getFirstGameObjectOfType(Elevator); elevator != nil {
				setElevatorState(elevator, .Interactable)
			} else {
				panic("Couldn't make elevator interactable because there was no elevator")
			}
			setElevator3DState(&global.elevator3D, .Invisible)
		}
	case .Looking:
		player.lookingStateData.yawTween = createFinishedTween(player.yaw)
		player.lookingStateData.pitchTween = createFinishedTween(player.pitch)
	case .Moving:
		if global.elevator3D.state == .Invisible {
			setElevator3DState(&global.elevator3D, .Idle)
		}
		if previousState == .Inactive {
			setElevator3DDoorState(&global.elevator3D, true, true, 0.0)
			setElevator3DDoorState(&global.elevator3D, false, false, 5.0)
		}
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
updatePlayer3D :: proc(self: ^Player3D) {
	switch self.state {
	case .Uninitialized:
	case .Inactive:
	case .Looking:
		data := &self.lookingStateData
		if rl.IsKeyPressed(.LEFT) {
			goalYaw := data.yawTween.range.(TweenF32Range).to
			data.yawTween = createTween(
				TweenF32Range{self.yaw, goalYaw + PLAYER_3D_LOOKING_HORIZONTAL_ANGLE_INCREMENT},
				.InvExp,
				PLAYER_3D_LOOKING_HORIZONTAL_DURATION,
			)
			data.horizontalState = enumNext(data.horizontalState)
		} else if rl.IsKeyPressed(.RIGHT) {
			goalYaw := data.yawTween.range.(TweenF32Range).to
			data.yawTween = createTween(
				TweenF32Range{self.yaw, goalYaw - PLAYER_3D_LOOKING_HORIZONTAL_ANGLE_INCREMENT},
				.InvExp,
				PLAYER_3D_LOOKING_HORIZONTAL_DURATION,
			)
			data.horizontalState = enumPrev(data.horizontalState)
		}
		self.yaw = updateAndStepTween(&data.yawTween).(f32)

		if rl.IsKeyPressed(.UP) && !isEnumLast(data.verticalState) {
			data.verticalState = enumNext(data.verticalState)
			angleIncrement := PLAYER_3D_LOOKING_VERTICAL_ANGLE_INCREMENT
			data.pitchTween = createTween(
				TweenF32Range {
					self.pitch,
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
					self.pitch,
					-angleIncrement + angleIncrement * f32(data.verticalState),
				},
				.InvExp,
				PLAYER_3D_LOOKING_VERTICAL_DURATION,
			)
		}
		self.pitch = updateAndStepTween(&data.pitchTween).(f32)
		player3DApplyCameraRotation(self)

		if tweenIsFinished(data.yawTween) && tweenIsFinished(data.pitchTween) {
			if data.horizontalState == .Forward && data.verticalState == .Middle {
				if rl.IsKeyPressed(.LEFT_SHIFT) {
					movePlayer3D(self, global.camera3D.position, PLAYER_3D_PANEL_POSITION, .Panel)
				} else if rl.IsKeyPressed(.Z) && isElevator3DDoorOpen(&global.elevator3D) {
					movePlayer3D(
						self,
						global.camera3D.position,
						PLAYER_3D_OUTSIDE_POSITION,
						.Inactive,
					)
				}
			}
		}
	case .Moving:
		global.camera3D.position =
		updateAndStepTween(&self.movingStateData.movementTween).(rl.Vector3)
		global.camera3D.target = global.camera3D.position + self.movingStateData.look
		if tweenIsFinished(self.movingStateData.movementTween) {
			setPlayer3DState(self, self.movingStateData.nextState)
		}
		player3DApplyCameraRotation(self)
	case .Panel:
		if rl.IsKeyPressed(.DOWN) {
			movePlayer3D(self, global.camera3D.position, PLAYER_3D_INSIDE_POSITION, .Looking)
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
ELEVATOR_3D_PANEL_BUTTON_COUNT :: 6
ELEVATOR_3D_PANEL_RENDER_TEXTURE_WIDTH :: 180
ElevatorPanelData :: struct {
	buttonState:         [ELEVATOR_PANEL_BUTTON_COUNT.x][ELEVATOR_PANEL_BUTTON_COUNT.y]i32,
	buttonSeparation:    rl.Vector2,
	buttonArea:          rl.Rectangle,
	buttonPressStack:    [ELEVATOR_3D_PANEL_BUTTON_COUNT]i32,
	buttonPressCount:    i32,
	knobState:           [2]f32,
	knobSeparation:      rl.Vector2,
	knobArea:            rl.Rectangle,
	sliderState:         [3]f32,
	sliderSeparation:    rl.Vector2,
	sliderArea:          rl.Rectangle,
	bigButtonSeparation: rl.Vector2,
	bigButtonArea:       rl.Rectangle,
	bigButtonSize:       rl.Vector2,
	screenArea:          rl.Rectangle,
	depthIndicatorArea:  rl.Rectangle,
	depth:               i32,
}
elevatorPanel3DInput :: proc(panel: ^ElevatorPanelData, position: rl.Vector2) {
	if pointInRectangle(position, panel.buttonArea) {
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
			if global.elevator3D.state == .Idle {
				if panel.buttonState[relativeButtonIndex.x][relativeButtonIndex.y] == 1 {
					buttonStackIndex: i32 = 0
					for i in 0 ..< panel.buttonPressCount {
						if panel.buttonPressStack[i] ==
						   relativeButtonIndex.y +
							   relativeButtonIndex.x * ELEVATOR_PANEL_BUTTON_COUNT.y {
							for j := i + 1; j < panel.buttonPressCount; j += 1 {
								panel.buttonPressStack[j - 1] = panel.buttonPressStack[j]
							}
							break
						}
					}
					panel.buttonState[relativeButtonIndex.x][relativeButtonIndex.y] = 0
					panel.buttonPressCount -= 1
				} else {
					panel.buttonPressStack[panel.buttonPressCount] =
						relativeButtonIndex.y +
						relativeButtonIndex.x * ELEVATOR_PANEL_BUTTON_COUNT.y
					panel.buttonState[relativeButtonIndex.x][relativeButtonIndex.y] = 1
					panel.buttonPressCount += 1
				}
				if panel.buttonPressCount >= ELEVATOR_3D_PANEL_BUTTON_COUNT {
					setElevator3DState(&global.elevator3D, .Leaving)
				}
			}
		}
	} else if pointInRectangle(position, panel.knobArea) {
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
	} else if pointInRectangle(position, panel.sliderArea) {
		sliderAreaStart := rl.Vector2{panel.sliderArea.x, panel.sliderArea.y}
		relativePosition := position - sliderAreaStart
		sliderIndex := i32(math.floor(relativePosition.x / panel.sliderSeparation.x))
		panel.sliderState[sliderIndex] = rand.float32() * panel.sliderArea.height
		rl.PlaySound(getSound(.ElevatorPanelSlider))
	} else if pointInRectangle(position, panel.bigButtonArea) {
		bigButtonAreaStart := rl.Vector2{panel.bigButtonArea.x, panel.bigButtonArea.y}
		relativePosition := (position - bigButtonAreaStart) / panel.bigButtonSeparation
		relativePositionFloored := rl.Vector2 {
			math.floor(relativePosition.x),
			math.floor(relativePosition.y),
		}
		bigButtonPosition :=
			bigButtonAreaStart + panel.bigButtonSeparation * relativePositionFloored
		bigButtonRectangle := rl.Rectangle {
			bigButtonAreaStart.x,
			bigButtonAreaStart.y,
			panel.bigButtonSize.x,
			panel.bigButtonSize.y,
		}
		if pointInRectangle(position, bigButtonRectangle) {
			rl.PlaySound(getSound(.ElevatorPanelButton))
			switch (int(relativePositionFloored.x)) {
			case 0:
				if global.elevator3D.state == .Idle {
					setElevator3DDoorState(&global.elevator3D, true, false, 0.4)
				}
			case 1:
				if global.elevator3D.state == .Idle {
					setElevator3DDoorState(&global.elevator3D, false, false, 0.4)
				}
			case 2:
			// TODO: Play ringing sound
			}
		} else {
			panic("No Elevator3D in level, ElevatorPanel3D depends on Elevator3D")
		}
	}
}
ELEVATOR_PANEL_BUTTON_COUNT: iVector2 : {3, 8}
Elevator3DState :: enum {
	Invisible,
	Idle,
	Leaving,
	Transit,
}
Elevator3DTransitStateData :: struct {
	timer:    Timer,
	duration: f32,
}
Elevator3D :: struct {
	state:              Elevator3DState,
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
	doorsTween:         Tween,
	doorOpenness:       f32,
	transitStateData:   Elevator3DTransitStateData,
}
setElevator3DDoorState :: proc(e: ^Elevator3D, open: bool, instant: bool, delay: f32) {
	if instant {
		if open {
			e.doorsTween = createFinishedTween(1.0)
		} else {
			e.doorsTween = createFinishedTween(0.0)
		}
	} else {
		if open {
			e.doorsTween = createTween(TweenF32Range{0.0, 1.0}, .Hermite, 2.5, delay)
		} else {
			e.doorsTween = createTween(TweenF32Range{1.0, 0.0}, .Hermite, 2.5, delay)
		}
	}
}
isElevator3DDoorOpen :: proc(e: ^Elevator3D) -> bool {
	return(
		(e.doorsTween.range.(TweenF32Range).to == 1.0 &&
			getTweenProgressDurationOnly(e.doorsTween) > 0.5) ||
		(e.doorsTween.range.(TweenF32Range).to == 0.0 &&
				getTweenProgressDurationOnly(e.doorsTween) < 0.5) \
	)
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
	self := Elevator3D {
		state = .Invisible,
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
				60.0,
				24.0 * f32(ELEVATOR_PANEL_BUTTON_COUNT.x),
				24.0 * f32(ELEVATOR_PANEL_BUTTON_COUNT.y),
			},
			buttonSeparation = {24.0, 24.0},
			knobArea = {110.0, 60.0, 44.0, 44.0 * 2},
			knobSeparation = {0.0, 44.0},
			sliderArea = {101.0, 167.0, 24.0 * 3.0, 80.0},
			sliderSeparation = {24.0, 0.0},
			bigButtonArea = {14.0, 263.0, 39.0 * 3.0, 30.0},
			bigButtonSeparation = {39.0, 0.0},
			bigButtonSize = {30.0, 30.0},
			screenArea = {16.0, 12.0, 102.0, 38.0},
			depthIndicatorArea = {16.0 + 102.0 + 8.0, 12.0, 38.0, 38.0},
		},
		transitStateData = {timer = {}, duration = 5.0},
		lightFrameIndex = 1.0,
		doorsTween = createFinishedTween(f32(1.0)),
		doorOpenness = 0.0,
	}
	setElevator3DState(&self, .Invisible)
	return self
}
toggleElevatorLights :: proc(e: ^Elevator3D) {
	if e.lightFrameIndex == 0.0 {
		e.lightFrameIndex = 1.0
	} else {
		e.lightFrameIndex = 0.0
	}
	setLightStatus(i32(e.lightFrameIndex))
}
updateElevator3D :: proc(e: ^Elevator3D) {
	switch e.state {
	case .Invisible:
	case .Idle:
	case .Leaving:
		if tweenIsFinished(e.doorsTween) {
			setElevator3DState(e, .Transit)
		}
	case .Transit:
		stateData := &e.transitStateData
		updateTimer(&stateData.timer)
		elevatorSoundVolume := math.smoothstep(cast(f32)0.05, cast(f32)0.2, stateData.timer.time)
		rl.SetSoundVolume(getSound(.ElevatorMovingLoop), elevatorSoundVolume)
		if isTimerProgressTimestamp(stateData.timer, 0.5) {
			loadLevel(.UnrulyLand)
		}
		if isTimerFinished(e.transitStateData.timer) {
			setElevator3DState(e, .Idle)
		}
	}
	tweenWasWaiting := tweenIsWaiting(e.doorsTween)
	e.doorOpenness = updateAndStepTween(&e.doorsTween).(f32)
	e.leftDoorModel.transform = rl.MatrixTranslate(0.0, 0.0, e.doorOpenness * 2.0)
	e.rightDoorModel.transform = rl.MatrixTranslate(0.0, 0.0, -e.doorOpenness * 2.0)
	global.musicLPFFrequency = 90.0 + (44100.0 - 90.0) * e.doorOpenness

	if tweenWasWaiting && !tweenIsWaiting(e.doorsTween) {
		sounds := [?]rl.Sound {
			getSound(.ElevatorDoor1),
			getSound(.ElevatorDoor2),
			getSound(.ElevatorDoor3),
		}
		rl.PlaySound(rand.choice(sounds[:]))
	}
}
drawElevator3D :: proc(e: ^Elevator3D) {
	if e.state == .Invisible {
		return
	}
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

	applyLightToShader(engine.defaultMaterial3D.shader)
	rl.DrawMesh(
		e.mainModel.meshes[Elevator3DModelMeshes.PanelBox],
		engine.defaultMaterial3D,
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

	rl.DrawMesh(e.leftDoorModel.meshes[0], engine.defaultMaterial3D, e.leftDoorModel.transform)
	rl.DrawMesh(e.rightDoorModel.meshes[0], engine.defaultMaterial3D, e.rightDoorModel.transform)
}
setElevator3DState :: proc(e: ^Elevator3D, newState: Elevator3DState) {
	if e.state == newState {
		return
	}
	switch e.state {
	case .Invisible:
	case .Idle:
	case .Leaving:
	case .Transit:
		rl.PlaySound(getSound(.ElevatorMovingEnd))
		rl.StopSound(getSound(.ElevatorMovingLoop))
		e.panelData.buttonPressCount = 0
	}

	previousState := e.state
	e.state = newState
	fmt.println(e.state)

	switch e.state {
	case .Invisible:
		rl.StopSound(getSound(.ElevatorIdleLoop))
	case .Idle:
		if previousState == .Invisible {
			rl.PlaySound(getSound(.ElevatorIdleLoop))
		}
		for x in 0 ..< ELEVATOR_PANEL_BUTTON_COUNT.x {
			for y in 0 ..< ELEVATOR_PANEL_BUTTON_COUNT.y {
				e.panelData.buttonState[x][y] = 0
			}
		}
		setElevator3DDoorState(e, true, false, 0.0)
	case .Leaving:
		if isElevator3DDoorOpen(e) {
			setElevator3DDoorState(e, false, false, 0.0)
		}
	case .Transit:
		e.transitStateData.timer = createTimer(5.0)
		rl.PlaySound(getSound(.ElevatorMovingStart))
		rl.PlaySound(getSound(.ElevatorMovingLoop))
		rl.SetSoundVolume(getSound(.ElevatorMovingLoop), 0.0)
	}
}
renderElevator3DPanelTexture :: proc(renderTexture: rl.RenderTexture, data: ^ElevatorPanelData) {
	beginModeStacked(getZeroCamera2D(), renderTexture)
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

	buttonSymbolSprite := createSprite(getSpriteDef(.ElevatorPanelSymbols))
	buttonSizeHalved := cast(f32)getSpriteDef(.ElevatorPanelButton).frame_width / 2.0
	for x in 0 ..< ELEVATOR_PANEL_BUTTON_COUNT.x {
		for y in 0 ..< ELEVATOR_PANEL_BUTTON_COUNT.y {
			position :=
				rl.Vector2{f32(x), f32(y)} * data.buttonSeparation +
				{data.buttonArea.x, data.buttonArea.y}
			setSpriteFrame(&buttonSymbolSprite, y + x * ELEVATOR_PANEL_BUTTON_COUNT.y)
			drawSpriteEx(buttonSymbolSprite, position, {1.0, 1.0}, {0, 0, 0, 224})
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

	bigButtonTexture := getTexture(.ElevatorPanelBigButtons)
	rl.DrawTextureV(bigButtonTexture, {data.bigButtonArea.x, data.bigButtonArea.y}, rl.WHITE)

	rl.DrawRectangleRec(data.screenArea, rl.BLACK)
	screenContentDrawStart := rl.Vector2{data.screenArea.x, data.screenArea.y} + 4.0
	for i in 0 ..< data.buttonPressCount {
		setSpriteFrame(&buttonSymbolSprite, data.buttonPressStack[i])
		symbolOffset := rl.Vector2{cast(f32)((buttonSymbolSprite.def.frame_width - 7) * i), 0.0}
		drawSpriteEx(
			buttonSymbolSprite,
			screenContentDrawStart + symbolOffset,
			{1.0, 1.0},
			rl.ORANGE,
		)
	}

	rl.DrawRectangleRec(data.depthIndicatorArea, rl.BLACK)
	depthTextPosition := getRlRectangleCenter(data.depthIndicatorArea)
	drawTextAligned(
		rl.TextFormat("%i", data.depth),
		depthTextPosition,
		rl.GetFontDefault(),
		32.0,
		rl.GREEN,
		.Center,
		.Middle,
	)
	endModeStacked()
}
destroyElevator3D :: proc(e: ^Elevator3D) {
	rl.UnloadRenderTexture(e.panelRenderTexture)
}
