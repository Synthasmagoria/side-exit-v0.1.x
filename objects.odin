package game
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:mem"
import "core:strings"
import rl "lib/raylib"

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
createPlayer :: proc(alloc: Alloc) -> ^Player {
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
createElevator :: proc(alloc: Alloc) -> ^Elevator {
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
			movePlayer3D(
				&global.player3D,
				PLAYER_3D_OUTSIDE_POSITION,
				PLAYER_3D_INSIDE_POSITION,
				.Looking,
			)
		}
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

StarBg :: struct {
	genTex:     rl.Texture,
	frameSize:  rl.Vector2,
	frameIndex: f32,
	frameSpd:   f32,
	frameCount: i32,
	scroll:     rl.Vector2,
	scrollSpd:  rl.Vector2,
	object:     ^GameObject,
}
createStarBackground :: proc(levelAlloc: Alloc) -> ^StarBg {
	self := new(StarBg, levelAlloc)
	self.genTex = web10CreateTexture({128, 128}, getSpriteDef(.Star), 16)
	self.frameSize = {128.0, 128.0}
	self.frameSpd = 4.0
	self.frameCount = getSpriteDef(.Star).frame_count
	self.scrollSpd = rl.Vector2{30.0, 30.0}
	self.object = createGameObject(
		StarBg,
		self,
		drawProc = cast(proc(_: rawptr))drawStarBg,
		destroyProc = cast(proc(_: rawptr))destroyStarBg,
	)
	return self
}
drawStarBg :: proc(self: ^StarBg) {
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
		{self.object.pos.x, self.object.pos.y, WINDOW_WIDTH, WINDOW_HEIGHT},
	)
	rl.EndShaderMode()
}
destroyStarBg :: proc(self: ^StarBg) {
	rl.UnloadTexture(self.genTex)
}

HubGraphics :: struct {
	object: ^GameObject,
}
createHubGraphics :: proc(levelAlloc: Alloc) -> ^HubGraphics {
	self := new(HubGraphics, levelAlloc)
	self.object = createGameObject(
		HubGraphics,
		self,
		drawProc = cast(proc(_: rawptr))drawHubGraphics,
	)
	return self
}
drawHubGraphics :: proc(self: ^HubGraphics) {
	rl.DrawTextureV(getTexture(.HubBackground), {0.0, 0.0}, rl.WHITE)
	rl.DrawTextureV(getTexture(.HubBuilding), {0.0, 0.0}, rl.WHITE)
}
