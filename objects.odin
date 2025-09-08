package game
import rl "vendor:raylib"
import "core:fmt"
import "core:math/linalg"
import "core:math"

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
createPlayer :: proc(alloc: Alloc, pos: rl.Vector2) -> ^Player {
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
	self.object.pos = pos
	self.object.colRec = {7.0, 3.0, 12.0, 20.0}
	return self
}
updatePlayer :: proc(self: ^Player) {
	rightInput := rl.IsKeyDown(.RIGHT)
	leftInput := rl.IsKeyDown(.LEFT)
	walkInput := f32(int(rightInput)) - f32(int(leftInput))

	onFloor :=
		chunkCollision(getObjAbsColRec(self.object, {0.0, 1.0})) != nil &&
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
		} else if self.airjumpIndex < self.airjumpCount {
			self.velocity.y = -self.airjumpStr
			self.airjumpIndex += 1
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
	self.object.pos = moveAndCollideResult.newPos
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
makeAbsoluteColRec :: proc(colRec: rl.Rectangle, pos: rl.Vector2) -> rl.Rectangle {
	return {colRec.x + pos.x, colRec.y + pos.y, colRec.width, colRec.height}
}
MoveAndCollidePlayerResult :: struct {
	newPos:      rl.Vector2,
	newVelocity: rl.Vector2,
}
moveAndCollidePlayer :: proc(
	pos: rl.Vector2,
	colRec: rl.Rectangle,
	velocity: rl.Vector2,
	facing: f32,
) -> MoveAndCollidePlayerResult {
	result := MoveAndCollidePlayerResult {
		newPos      = pos,
		newVelocity = velocity,
	}
	absColRecNext := makeAbsoluteColRec(colRec, result.newPos + result.newVelocity)
	switch rect in chunkCollision(absColRecNext) {
	case rl.Rectangle:
		absColRecVert := makeAbsoluteColRec(colRec, result.newPos + {0.0, result.newVelocity.y})
		switch recVert in chunkCollision(absColRecVert) {
		case rl.Rectangle:
			vertTrajectory := math.sign(result.newVelocity.y)
			if (vertTrajectory == 1.0) {
				result.newPos.y = recVert.y - colRec.y - colRec.height - 1.0
			} else {
				result.newPos.y = recVert.y + recVert.height - colRec.y + 1.0
			}
			result.newVelocity.y = 0.0
		case nil:
			result.newPos.y += result.newVelocity.y
		}

		absColRecHor := makeAbsoluteColRec(colRec, result.newPos + {result.newVelocity.x, 0.0})
		switch recHor in chunkCollision(absColRecHor) {
		case rl.Rectangle:
			if (facing == 1.0) {
				result.newPos.x = recHor.x - colRec.x - colRec.width - 1.0
			} else {
				result.newPos.x = recHor.x + recHor.width - colRec.x + 1.0
			}
		case nil:
			result.newPos.x += result.newVelocity.x
		}
	case nil:
		result.newPos += result.newVelocity
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
    Leaving,
}
ElevatorArrivingStateData :: struct {
    movementTween: Tween,
    alphaTween: Tween,
}
ElevatorLeavingStateData :: struct {
    movementTween: Tween,
    alphaTween: Tween,
}
Elevator :: struct {
	interactionArrowSpr: Sprite,
	drawOffset: rl.Vector2,
	object: ^GameObject,
	player: ^Player,
	state: ElevatorState,
	arrivingStateData: ElevatorArrivingStateData,
	leavingStateData: ElevatorLeavingStateData,
	blend: rl.Color,
}
createElevator :: proc(alloc: Alloc, pos: rl.Vector2) -> ^Elevator {
	data := new(Elevator, alloc)
	data.interactionArrowSpr = createSprite(getSpriteDef(.InteractionIndicationArrow))
	data.state = .Gone
	data.drawOffset = {0.0, -224.0}
	data.blend = rl.WHITE
	data.object = createGameObject(
		Elevator,
		data,
		updateProc = cast(proc(_: rawptr))updateElevator,
	)
	setElevatorState(data, .Gone)
	data.object.pos = pos
	data.object.colRec = getTextureRec(getTexture(.Elevator))
	return data
}
updateElevator :: proc(self: ^Elevator) {
    switch (self.state) {
    case .Gone:
        if player := getFirstGameObjectOfType(Player); player != nil {
            if linalg.distance(player.pos, self.object.pos) < 64.0 {
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
            if linalg.distance(player.pos, self.object.pos) >= 64.0 {
                setElevatorState(self, .Leaving)
            }
        }
    case .Leaving:
        self.drawOffset = updateAndStepTween(&self.leavingStateData.movementTween).(rl.Vector2)
        self.blend.a = updateAndStepTween(&self.leavingStateData.alphaTween).(u8)
        if tweenIsFinished(self.leavingStateData.alphaTween) && tweenIsFinished(self.leavingStateData.alphaTween) {
            setElevatorState(self, .Gone)
        }
    }

	rl.DrawTextureV(getTexture(.Elevator), self.object.pos + self.drawOffset, self.blend)
	// if colObj := objectCollisionType(self.object, Player, {0.0, 0.0}); colObj != nil {
	// 	aboveOtherCenter := getObjCenterPosition(colObj^) - {0.0, colObj.colRec.height}
	// 	drawSpriteEx(self.interactionArrowSpr, aboveOtherCenter, {1.0, 1.0})
	// 	updateSprite(&self.interactionArrowSpr)
	// 	if rl.IsKeyPressed(.UP) {
	// 		player := cast(^Player)colObj.data
	// 		player.frozen = 1
	// 		self.player = player
	// 	}
	// }
	// if (self.player != nil && self.player.frozen == 1) {
	// 	if rl.IsKeyPressed(.BACKSPACE) {
	// 		self.player.frozen = 0
	// 		self.player = nil
	// 	}
	// }
}
setElevatorState :: proc(self: ^Elevator, newState: ElevatorState) {
    if (self.state == newState) {
        return
    }
    self.state = newState
    switch (self.state) {
    case .Gone:
        self.blend = {255, 255, 255, 0}
    case .Arriving:
        self.blend = rl.WHITE
        self.arrivingStateData.movementTween = createTween(TweenVector2Range{{0.0, -224.0}, {0.0, 0.0}}, .InvExp, 2.0)
        self.arrivingStateData.alphaTween = createTween(TweenU8Range{0, 255}, .Linear, 0.7)
    case .Interactable:
    case .Leaving:
        self.blend = rl.WHITE
        self.leavingStateData.movementTween = createTween(TweenVector2Range{{0.0, 0.0}, {0.0, -224.0}}, .Exp, 2.0)
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
createStarBg :: proc(alloc: Alloc) -> ^StarBg {
    self := new(StarBg, alloc)
	self.genTex = web10CreateTexture({128, 128}, getSpriteDef(.Star), 16)
	self.frameSize = {128.0, 128.0}
	self.frameSpd = 4.0
	self.frameCount = getSpriteDef(.Star).frame_count
	self.scrollSpd = rl.Vector2{30.0, 30.0}
	self.object = createGameObject(
	    StarBg,
		self,
		drawProc = cast(proc(_: rawptr))drawStarBg,
		destroyProc = cast(proc(_: rawptr))destroyStarBg)
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
	drawTextureRecDest(self.genTex, {self.object.pos.x, self.object.pos.y, WINDOW_WIDTH, WINDOW_HEIGHT})
	rl.EndShaderMode()
}
destroyStarBg :: proc(self: ^StarBg) {
    rl.UnloadTexture(self.genTex)
}
