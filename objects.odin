package game
import rl "vendor:raylib"
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
	data := new(Player, alloc)
	data.idleSpr = createSprite(getSpriteDef(.SynthIdle))
	data.walkSpr = createSprite(getSpriteDef(.SynthWalk))
	data.currentSpr = &data.idleSpr
	data.maxVelocity = {6.5, 6.5}
	data.jumpStr = 7.0
	data.walkSpd = 2.0
	data.verticalGrav = 0.5
	data.verticalDampen = 0.7
	data.scale = {1.0, 1.0}
	data.airjumpStr = 5.8
	data.airjumpCount = 1
	data.airjumpIndex = 0
	data.object = createGameObject(
		Player,
		data,
		updateProc = cast(proc(_: rawptr))updatePlayer,
		drawProc = cast(proc(_: rawptr))drawPlayer,
	)
	data.object.pos = pos
	data.object.colRec = {7.0, 3.0, 12.0, 20.0}
	return data
}
updatePlayer :: proc(player: ^Player) {
	rightInput := rl.IsKeyDown(.RIGHT)
	leftInput := rl.IsKeyDown(.LEFT)
	walkInput := f32(int(rightInput)) - f32(int(leftInput))

	onFloor :=
		chunkCollision(getObjAbsColRec(player.object, {0.0, 1.0})) != nil &&
		player.velocity.y >= 0.0
	if onFloor {
		player.airjumpIndex = 0
	} else {
		player.velocity.y += player.verticalGrav
	}

	player.velocity.x = walkInput * player.walkSpd * f32(player.frozen ~ 1)
	if 0.0 < math.abs(player.velocity.x) {
		player.scale.x = math.abs(player.scale.x) * math.sign(player.velocity.x)
	}
	jumpInput := rl.IsKeyPressed(.SPACE)
	if jumpInput {
		if onFloor {
			player.velocity.y = -player.jumpStr
			onFloor = false
		} else if player.airjumpIndex < player.airjumpCount {
			player.velocity.y = -player.airjumpStr
			player.airjumpIndex += 1
		}
	}
	if !onFloor && player.velocity.y < 0.0 && rl.IsKeyReleased(.SPACE) {
		player.velocity.y *= player.verticalDampen
	}

	player.velocity = rl.Vector2Clamp(player.velocity, -player.maxVelocity, player.maxVelocity)

	moveAndCollideResult := moveAndCollidePlayer(
		player.object.pos,
		player.object.colRec,
		player.velocity,
		math.sign(player.scale.x),
	)
	player.object.pos = moveAndCollideResult.newPos
	player.velocity = moveAndCollideResult.newVelocity
}
drawPlayer :: proc(self: ^Player) {
	if self.velocity.x > 0.0 {
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

Elevator :: struct {
	tex:                 rl.Texture,
	interactionArrowSpr: Sprite,
	object:              ^GameObject,
	player:        ^Player,
	panel:         ^ElevatorPanel,
}
createElevator :: proc(alloc: Alloc, pos: rl.Vector2) -> ^Elevator {
	data := new(Elevator, alloc)
	data.tex = getTexture(.Elevator)
	data.interactionArrowSpr = createSprite(getSpriteDef(.InteractionIndicationArrow))
	data.object = createGameObject(
		Elevator,
		data,
		startProc = cast(proc(_: rawptr))startElevator,
		updateProc = cast(proc(_: rawptr))updateAndDrawElevator,
	)

	data.object.pos = pos
	data.object.colRec = getTextureRec(data.tex)
	return data
}
startElevator :: proc(self: ^Elevator) {
	objs := getGameObjectsOfType(Elevator)
	if len(objs) > 0 {
		self.panel = cast(^ElevatorPanel)objs[0].data
	}
}
updateAndDrawElevator :: proc(self: ^Elevator) {
	rl.DrawTextureV(self.tex, self.object.pos, rl.WHITE)
	if colObj := objectCollisionType(self.object, Player, {0.0, 0.0}); colObj != nil {
		aboveOtherCenter := getObjCenterPosition(colObj^) - {0.0, colObj.colRec.height}
		drawSpriteEx(self.interactionArrowSpr, aboveOtherCenter, {1.0, 1.0})
		updateSprite(&self.interactionArrowSpr)
		if rl.IsKeyPressed(.UP) {
			player := cast(^Player)colObj.data
			player.frozen = 1
			self.player = player
		}
	}
	if (self.player != nil && self.player.frozen == 1) {
		if rl.IsKeyPressed(.BACKSPACE) {
			self.player.frozen = 0
			self.player = nil
		}
	}
}

ElevatorPanel :: struct {
	bgTex: rl.Texture,
	tex:   rl.Texture,
}
createElevatorPanel :: proc(alloc: Alloc, pos: rl.Vector2) -> ^ElevatorPanel {
	data := new(ElevatorPanel, alloc)
	data.bgTex = getTexture(.ElevatorPanelBg)
	data.tex = getTexture(.ElevatorPanel)
	object := createGameObject(
		ElevatorPanel,
		data,
		updateProc = cast(proc(_: rawptr))updateAndDrawElevatorPanel,
	)
	return data
}
updateAndDrawElevatorPanel :: proc(ep: ^ElevatorPanel) {
	uiPos := camera.target - {WINDOW_WIDTH, WINDOW_HEIGHT} / 2.0
	bgTexSrc := getTextureRec(ep.bgTex)
	bgTexDest := rl.Rectangle{uiPos.x, uiPos.y, WINDOW_WIDTH, WINDOW_HEIGHT}
	rl.DrawTexturePro(ep.bgTex, bgTexSrc, bgTexDest, {0.0, 0.0}, 0.0, rl.WHITE)
	texSrc := getTextureRec(ep.tex)
	texDest := rl.Rectangle {
		WINDOW_WIDTH / 2.0 - texSrc.width / 2.0,
		WINDOW_HEIGHT / 2.0 - texSrc.height / 2.0,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
	}
	rl.DrawTexturePro(ep.tex, texSrc, texDest, {0.0, 0.0}, 0.0, rl.WHITE)
}
