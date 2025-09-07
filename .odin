package main

import "core:fmt"
import math "core:math"
import linalg "core:math/linalg"
import rand "core:math/rand"
import mem "core:mem"
import "core:reflect"
import string_util "core:strings"
import rl "vendor:raylib"

Alloc :: mem.Allocator

MusicName :: enum {
	KowloonSmokeBreak,
	_Count,
}
loadMusicStream :: proc(ind: MusicName) -> rl.Music {
	context.allocator = context.temp_allocator
	name, ok := reflect.enum_name_from_value(ind)
	_ = ok
	fileName := transmute([]byte)string_util.clone(name)
	fileName[0] = charLower(fileName[0])
	filePath := [?]string{"aud/", cast(string)fileName, ".mp3"}
	joinedPath := string_util.join(filePath[:], "")
	return rl.LoadMusicStream(string_util.clone_to_cstring(joinedPath))
}

TextureName :: enum {
	Star,
	SynthIdle,
	SynthIdleBack,
	SynthWalk,
	SynthWalkBack,
	White32,
	Elevator,
	ElevatorPanel,
	ElevatorPanelBg,
	ElevatorPanelButtonHint,
	ElevatorPanelButtonInputIndicator,
	ElevatorPanelKnob,
	ElevatorPanelKnobInputHint,
	ElevatorPanelLever,
	ElevatorPanelLeverInputHint,
	InteractionIndicationArrow,
	_Count,
}
globalTextures: [TextureName._Count]rl.Texture
getTexture :: proc(ind: TextureName) -> rl.Texture {
	return globalTextures[ind]
}
loadTextures :: proc() {
	context.allocator = context.temp_allocator
	texNames := reflect.enum_field_names(TextureName)
	for name, i in texNames[0:len(texNames) - 1] {
		n := transmute([]u8)string_util.clone(name)
		n[0] = charLower(n[0])
		path := string_util.join({"tex/", cast(string)n, ".png"}, "")
		globalTextures[i] = rl.LoadTexture(string_util.clone_to_cstring(path))
	}
}
unloadTextures :: proc() {
	for t in globalTextures {
		rl.UnloadTexture(t)
	}
}

globalSpriteDefs: [TextureName._Count]SpriteDef
getSpriteDef :: proc(ind: TextureName) -> SpriteDef {
	return globalSpriteDefs[ind]
}
_setSpriteDef :: proc(ind: TextureName, frame_w: i32, frame_spd: f32) {
	globalSpriteDefs[ind] = createSpriteDef(getTexture(ind), frame_w, frame_spd)
}
initSpriteDefs :: proc() {
	_setSpriteDef(.Star, 4, 8.0)
	_setSpriteDef(.SynthIdle, 24, 8.0)
	_setSpriteDef(.SynthIdleBack, 24, 8.0)
	_setSpriteDef(.SynthWalk, 24, 8.0)
	_setSpriteDef(.SynthWalkBack, 24, 8.0)
	_setSpriteDef(.InteractionIndicationArrow, 14, 8.0)
}

ShaderNames :: enum {
	AnimatedTextureRepeatPosition,
	_Count,
}
globalShaders: [ShaderNames._Count]rl.Shader
getShader :: proc(ind: ShaderNames) -> rl.Shader {
	return globalShaders[ind]
}

loadShaders :: proc() {
	context.allocator = context.temp_allocator
	names := reflect.enum_field_names(ShaderNames)
	for name, i in names[0:len(names) - 1] {
		n := transmute([]u8)string_util.clone(name)
		n[0] = charLower(n[0])
		vertPath := [?]string{"shd/", cast(string)n, ".vert"}
		fragPath := [?]string{"shd/", cast(string)n, ".frag"}
		globalShaders[i] = rl.LoadShader(
			string_util.clone_to_cstring(string_util.join(vertPath[:], "")),
			string_util.clone_to_cstring(string_util.join(fragPath[:], "")),
		)
	}
}
unloadShaders :: proc() {
	for shd in globalShaders {
		rl.UnloadShader(shd)
	}
}

charLower :: proc(c: u8) -> u8 {
	if c >= 'A' && c <= 'Z' {
		return c + ('a' - 'A')
	}
	return c
}

GameObject :: struct {
	update: proc(data: rawptr),
	data:   rawptr,
	pos:    rl.Vector2,
	colRec: rl.Rectangle,
	id:     i32,
	type:   typeid,
}
globalGameObjects: ^[dynamic]GameObject = nil
globalGameObjectIdCounter: i32 = min(i32)
createGameObject :: proc($T: typeid, update: proc(_: ^T), data: rawptr) -> ^GameObject {
	object := GameObject {
		update = cast(proc(_: rawptr))update,
		data   = data,
		id     = globalGameObjectIdCounter,
		type   = T,
	}
	append(globalGameObjects, object)
	globalGameObjectIdCounter += 1
	return &globalGameObjects[len(globalGameObjects) - 1]
}
objectCollision :: proc(object: ^GameObject, offset: rl.Vector2) -> ^GameObject {
	rec := getObjAbsColRec(object, offset)
	for i in 0 ..< len(globalGameObjects) {
		otherObject := &globalGameObjects[i]
		if object.id != otherObject.id && recInRec(rec, getObjAbsColRec(otherObject, {0.0, 0.0})) {
			return &globalGameObjects[i]
		}
	}
	return nil
}
objectCollisionType :: proc(object: ^GameObject, type: typeid, offset: rl.Vector2) -> ^GameObject {
	rec := getObjAbsColRec(object, offset)
	for i in 0 ..< len(globalGameObjects) {
		otherObject := &globalGameObjects[i]
		if object.id != otherObject.id &&
		   otherObject.type == type &&
		   recInRec(rec, getObjAbsColRec(otherObject, {0.0, 0.0})) {
			return &globalGameObjects[i]
		}
	}
	return nil
}
// TODO: objectCollisionList
getObjectCenter :: proc(object: ^GameObject) -> rl.Vector2 {
	return {
		object.colRec.x + object.colRec.width / 2.0,
		object.colRec.y + object.colRec.height / 2.0,
	}
}
getObjAbsColRec :: proc(object: ^GameObject, offset: rl.Vector2) -> rl.Rectangle {
	return {
		object.pos.x + object.colRec.x + offset.x,
		object.pos.y + object.colRec.y + offset.y,
		object.colRec.width,
		object.colRec.height,
	}
}

SpriteDef :: struct {
	tex:         rl.Texture,
	frame_count: i32,
	frame_w:     i32,
	frame_spd:   f32,
}
createSpriteDef :: proc(tex: rl.Texture, frame_w: i32, frame_spd: f32) -> SpriteDef {
	return {tex, tex.width / frame_w, frame_w, frame_spd}
}
Sprite :: struct {
	def:       SpriteDef,
	frame_t:   f32,
	frame_ind: i32,
}
createSprite :: proc(spr_def: SpriteDef) -> Sprite {
	return {spr_def, 0, 0.0}
}
getSpriteSourceRect :: proc(spr: Sprite, scale: rl.Vector2) -> rl.Rectangle {
	scaleSign: f32 = math.sign(scale.x)
	offX: i32 = scaleSign == 1.0 ? 0 : spr.def.frame_w
	return {
		cast(f32)(spr.frame_ind * spr.def.frame_w + offX),
		0.0,
		cast(f32)spr.def.frame_w * scaleSign,
		cast(f32)spr.def.tex.height,
	}
}
drawSpriteEx :: proc(spr: Sprite, pos: rl.Vector2, scale: rl.Vector2) {
	src := getSpriteSourceRect(spr, scale)
	frame_w := f32(spr.def.frame_w)
	size := rl.Vector2{frame_w, frame_w} * scale
	dest := rl.Rectangle{pos.x, pos.y, size.x, size.y}
	rl.DrawTexturePro(spr.def.tex, src, dest, {0.0, 0.0}, 0.0, rl.WHITE)
}
drawSpriteRect :: proc(spr: Sprite, dest: rl.Rectangle) {
	src := getSpriteSourceRect(spr, {1.0, 1.0})
	frame_w := f32(spr.def.tex.width)
	rl.DrawTexturePro(spr.def.tex, src, dest, {0.0, 0.0}, 0.0, rl.WHITE)
}
setSpriteFrame :: proc(spr: ^Sprite, frame: i32) {
	spr.frame_t = math.mod(f32(frame), f32(spr.def.frame_count))
	spr.frame_ind = i32(spr.frame_t)
}
updateSprite :: proc(spr: ^Sprite, t_step: f32 = TARGET_TIME_STEP) {
	spr.frame_t = math.mod(spr.frame_t + t_step * spr.def.frame_spd, f32(spr.def.frame_count))
	spr.frame_ind = i32(spr.frame_t)
}
advanceSpriteFrame :: proc(spr: ^Sprite) {
	spr.frame_t = math.mod(spr.frame_t + 1.0, f32(spr.def.frame_count))
	spr.frame_ind = i32(spr.frame_t)
}

web10CreateTexture :: proc(w: i32, h: i32, spr_def: SpriteDef, num: i32) -> rl.Texture {
	context.allocator = context.temp_allocator
	tex_w := w * spr_def.frame_count
	assert(tex_w <= MAX_TEXTURE_SIZE)
	spr_list := make([dynamic]Sprite, num, num)
	rect_list := make([dynamic]rl.Rectangle, num, num)
	frame_count := f32(spr_def.frame_count)
	tex_size := getTextureSize(spr_def.tex)
	for i: i32 = 0; i < num; i += 1 {
		spr_list[i] = createSprite(spr_def)
		setSpriteFrame(&spr_list[i], rand.int31_max(spr_def.frame_count))
		rect_list[i] = rl.Rectangle {
			math.floor(f32(rand.int31_max(w - spr_def.tex.width))),
			math.floor(f32(rand.int31_max(h - spr_def.tex.height))),
			tex_size.x,
			tex_size.y,
		}
	}

	rtex := rl.LoadRenderTexture(tex_w, h)
	defer rl.UnloadRenderTexture(rtex)
	rl.BeginTextureMode(rtex)
	rl.ClearBackground(rl.Color{0, 0, 0, 0})

	for i: i32 = 0; i < spr_def.frame_count; i += 1 {
		xoff := cast(f32)(i * w)
		for j: i32 = 0; j < num; j += 1 {
			pos := rl.Vector2{rect_list[j].x + xoff, rect_list[j].y}
			drawSpriteEx(spr_list[j], pos, rl.Vector2{1.0, 1.0})
			advanceSpriteFrame(&spr_list[j])
		}
	}

	rl.EndTextureMode()
	img := rl.LoadImageFromTexture(rtex.texture)
	return rl.LoadTextureFromImage(img)
}

getAppRtexSrcRect :: proc(rtex: rl.RenderTexture) -> rl.Rectangle {
	rtex_size := getTextureSize(rtex.texture)
	return {0.0, rtex_size.y, rtex_size.x, -rtex_size.y}
}

getAppRtexDestRect :: proc(rtex: rl.RenderTexture) -> rl.Rectangle {
	screen_size := rl.Vector2{cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()}
	rtex_size := getTextureSize(rtex.texture)
	if screen_size.x < screen_size.y {
		h := screen_size.x / rtex_size.x * rtex_size.y
		return {0.0, screen_size.y / 2.0 - h / 2.0, screen_size.x, h}
	} else {
		w := screen_size.y / rtex_size.y * rtex_size.x
		return {screen_size.x / 2.0 - w / 2.0, 0.0, w, screen_size.y}
	}
}
getAppRtexZoom :: proc() -> f32 {
	screenSize := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	rtexSize := rl.Vector2{WINDOW_WIDTH, WINDOW_HEIGHT}
	if screenSize.x < screenSize.y {
		return screenSize.x / rtexSize.x
	} else {
		return screenSize.y / rtexSize.y
	}
}

getTextureSize :: proc(tex: rl.Texture) -> rl.Vector2 {
	return {f32(tex.width), f32(tex.height)}
}
getTextureRec :: proc(tex: rl.Texture) -> rl.Rectangle {
	return {0.0, 0.0, f32(tex.width), f32(tex.height)}
}

drawAppRtex :: proc(rtex: rl.RenderTexture) {
	src := getAppRtexSrcRect(rtex)
	dest := getAppRtexDestRect(rtex)
	origin := rl.Vector2{0.0, 0.0}
	rl.DrawTexturePro(rtex.texture, src, dest, origin, 0.0, rl.WHITE)
}

MAX_TEXTURE_SIZE :: 4096
TARGET_FPS :: 60
TARGET_TIME_STEP :: 1.0 / cast(f32)TARGET_FPS
WINDOW_WIDTH :: 480
WINDOW_HEIGHT :: 360

RepeatingStarBg :: struct {
	shd:        rl.Shader,
	tex:        rl.Texture,
	texSize:    rl.Vector2,
	frameIndex: f32,
	frameSpd:   f32,
	frameCount: i32,
	scroll:     rl.Vector2,
	scrollSpd:  rl.Vector2,
}
createRepeatingStarBg :: proc(
	shd: rl.Shader,
	tex: rl.Texture,
	texSize: rl.Vector2,
	frameSpd: f32,
	frameCount: i32,
	scrollSpd: rl.Vector2,
) -> RepeatingStarBg {
	return {shd, tex, texSize, 0.0, frameSpd, frameCount, rl.Vector2{0.0, 0.0}, scrollSpd}
}
drawRepeatingStarBg :: proc(bg: ^RepeatingStarBg) {
	rl.BeginShaderMode(bg.shd)
	frameCountLoc := rl.GetShaderLocation(bg.shd, "frameCount")
	rl.SetShaderValue(bg.shd, frameCountLoc, &bg.frameCount, .INT)
	frameIndexLoc := rl.GetShaderLocation(bg.shd, "frameInd")
	rl.SetShaderValue(bg.shd, frameIndexLoc, &bg.frameIndex, .FLOAT)
	texSizeLoc := rl.GetShaderLocation(bg.shd, "texSize")
	rl.SetShaderValue(bg.shd, texSizeLoc, &bg.texSize, .VEC2)
	bg.frameIndex += TARGET_TIME_STEP * bg.frameSpd
	scrollPxLoc := rl.GetShaderLocation(bg.shd, "scrollPx")
	rl.SetShaderValue(bg.shd, scrollPxLoc, &bg.scroll, .VEC2)
	bg.scroll += bg.scrollSpd * TARGET_TIME_STEP
	drawTextureRecDest(bg.tex, {0.0, 0.0, WINDOW_WIDTH, WINDOW_HEIGHT})
	rl.EndShaderMode()
}

textureGetSourceRec :: proc(tex: rl.Texture) -> rl.Rectangle {
	return {0.0, 0.0, cast(f32)tex.width, cast(f32)tex.height}
}

drawTextureRecDest :: proc(tex: rl.Texture, dest: rl.Rectangle) {
	src := textureGetSourceRec(tex)
	rl.DrawTexturePro(tex, src, dest, rl.Vector2{0.0, 0.0}, 0.0, rl.WHITE)
}

ElevatorObject :: struct {
	tex:                 rl.Texture,
	interactionArrowSpr: Sprite,
	object:              ^GameObject,
}
createElevator :: proc(alloc: Alloc, pos: rl.Vector2) -> ^ElevatorObject {
	data := new(ElevatorObject, alloc)
	data.tex = getTexture(.Elevator)
	data.interactionArrowSpr = createSprite(getSpriteDef(.InteractionIndicationArrow))
	data.object = createGameObject(ElevatorObject, updateAndDrawElevator, data)

	data.object.pos = pos
	data.object.colRec = getTextureRec(data.tex)
	return data
}
updateAndDrawElevator :: proc(elevator: ^ElevatorObject) {
	rl.DrawTextureV(elevator.tex, elevator.object.pos, rl.WHITE)
	if colObj := objectCollisionType(elevator.object, PlayerObject, {0.0, 0.0}); colObj != nil {
		aboveOtherCenter := getObjectCenter(colObj) - {0.0, colObj.colRec.height}
		drawSpriteEx(elevator.interactionArrowSpr, aboveOtherCenter, {1.0, 1.0})
		fmt.println("yo")
	} else {
		fmt.println("no")
	}
}

PlayerObject :: struct {
	object:         ^GameObject,
	idleSpr:        Sprite,
	walkSpr:        Sprite,
	currentSpr:     ^Sprite,
	scale:          rl.Vector2,
	colRec:         rl.Rectangle,
	velocity:       rl.Vector2,
	maxVelocity:    rl.Vector2,
	walkSpd:        f32,
	verticalGrav:   f32,
	verticalDampen: f32,
	jumpStr:        f32,
	airjumpStr:     f32,
	airjumpCount:   i32,
	airjumpIndex:   i32,
}
createPlayer :: proc(alloc: Alloc, pos: rl.Vector2) -> ^PlayerObject {
	data := new(PlayerObject, alloc)
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
	data.object = createGameObject(PlayerObject, updateAndDrawPlayer, data)

	data.object.pos = pos
	data.object.colRec = {7.0, 3.0, 12.0, 20.0}

	return data
}
makeAbsoluteColRec :: proc(colRec: rl.Rectangle, pos: rl.Vector2) -> rl.Rectangle {
	return {colRec.x + pos.x, colRec.y + pos.y, colRec.width, colRec.height}
}
updateAndDrawPlayer :: proc(player: ^PlayerObject) {
	rightInput := rl.IsKeyDown(.RIGHT)
	leftInput := rl.IsKeyDown(.LEFT)
	walkInput := f32(int(rightInput)) - f32(int(leftInput))

	onFloor :=
		blockCollision(getObjAbsColRec(player.object, {0.0, 1.0})) != nil &&
		player.velocity.y >= 0.0
	if onFloor {
		player.airjumpIndex = 0
	} else {
		player.velocity.y += player.verticalGrav
	}

	player.velocity.x = walkInput * player.walkSpd
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

	moveAndCollideResult := playerMoveAndCollide(
		player.object.pos,
		player.object.colRec,
		player.velocity,
		math.sign(player.scale.x),
	)
	player.object.pos = moveAndCollideResult.newPos
	player.velocity = moveAndCollideResult.newVelocity

	if math.abs(walkInput) > 0.0 {
		playerSetSprite(player, &player.walkSpr)
	} else {
		playerSetSprite(player, &player.idleSpr)
	}
	drawSpriteEx(player.currentSpr^, player.object.pos, player.scale)
	updateSprite(player.currentSpr)
}
PlayerMoveAndCollideResult :: struct {
	newPos:      rl.Vector2,
	newVelocity: rl.Vector2,
}
playerMoveAndCollide :: proc(
	pos: rl.Vector2,
	colRec: rl.Rectangle,
	velocity: rl.Vector2,
	facing: f32,
) -> PlayerMoveAndCollideResult {
	result := PlayerMoveAndCollideResult {
		newPos      = pos,
		newVelocity = velocity,
	}
	absColRecNext := makeAbsoluteColRec(colRec, result.newPos + result.newVelocity)
	switch rect in blockCollision(absColRecNext) {
	case rl.Rectangle:
		absColRecVert := makeAbsoluteColRec(colRec, result.newPos + {0.0, result.newVelocity.y})
		switch recVert in blockCollision(absColRecVert) {
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
		switch recHor in blockCollision(absColRecHor) {
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
playerSetSprite :: proc(player: ^PlayerObject, spr: ^Sprite) {
	if (player.currentSpr != spr) {
		player.currentSpr = spr
		setSpriteFrame(player.currentSpr, 0)
	}
}

pointInRec :: proc(point: rl.Vector2, rectangle: rl.Rectangle) -> bool {
	return(
		point.x >= rectangle.x &&
		point.x < rectangle.x + rectangle.width &&
		point.y >= rectangle.y &&
		point.y < rectangle.y + rectangle.height \
	)
}
recInRec :: proc(a: rl.Rectangle, b: rl.Rectangle) -> bool {
	return(
		a.x + a.width >= b.x &&
		a.x < b.x + b.width &&
		a.y + a.height >= b.y &&
		a.y < b.y + b.height \
	)
}
BlockCollisionResult :: union {
	rl.Rectangle,
}
globalSolidBlocks: ^[dynamic]rl.Rectangle = nil
blockCollision :: proc(rec: rl.Rectangle) -> BlockCollisionResult {
	for block in globalSolidBlocks {
		if recInRec(rec, block) {
			return block
		}
	}
	return nil
}

fract :: proc(val: f32) -> f32 {
	return val - math.floor(val)
}
vector2Floor :: proc(v: rl.Vector2) -> rl.Vector2 {
	return {math.floor(v.x), math.floor(v.y)}
}
vector2Fract :: proc(v: rl.Vector2) -> rl.Vector2 {
	return {fract(v.x), fract(v.y)}
}
vector2Smoothstep :: proc(edgeA: rl.Vector2, edgeB: rl.Vector2, v: rl.Vector2) -> rl.Vector2 {
	return {math.smoothstep(edgeA.x, edgeB.x, v.x), math.smoothstep(edgeA.y, edgeB.y, v.y)}
}

deterministicFloat32Rand :: proc(st: rl.Vector2) -> f32 {
	hash := rl.Vector2DotProduct(st, {38.28459, 53.9385})
	return fract(math.abs(math.sin(hash) * 43028.28439))
}
// TODO: SIMD
deterministicValueNoise2d :: proc(st: rl.Vector2, octs: int) -> f32 {
	n: f32 = 0.0
	for i in 0 ..< octs {
		f := f32(i)
		nst := rl.Vector2{st.x * 2.0 * (f + 1.0) + 0.75 * f, st.y * 2.0 * (f + 1.0) + 0.495 * f}
		ist := vector2Floor(nst)
		fst := vector2Fract(nst)
		a := deterministicFloat32Rand(ist)
		b := deterministicFloat32Rand(ist + {1.0, 0.0})
		c := deterministicFloat32Rand(ist + {0.0, 1.0})
		d := deterministicFloat32Rand(ist + {1.0, 1.0})
		grad := vector2Smoothstep({0.0, 0.0}, {1.0, 1.0}, fst)
		nh := linalg.lerp(rl.Vector2{a, c}, rl.Vector2{b, d}, grad.x)
		nv := linalg.lerp(nh.x, nh.y, grad.y)
		significance := 1.0 / (f + 2.0)
		n += nv * significance
	}
	return n
}
Grid :: struct {
	data:      [dynamic]byte,
	width:     i32,
	blockSize: f32,
}
createGrid :: proc(alloc: Alloc, width: i32, height: i32, blockSize: f32) -> Grid {
	size := width * height
	return {make([dynamic]byte, size, size, alloc), width, blockSize}
}
fillGrid :: proc(grid: ^Grid, off: rl.Vector2, cutoff: f32) {
	gridHeight := i32(len(grid.data)) / grid.width
	gridSize := rl.Vector2{f32(grid.width), f32(gridHeight)}
	for i in 0 ..< len(grid.data) {
		ii := i32(i)
		f := rl.Vector2{f32((ii + 1) % grid.width), f32((ii + 1) / grid.width)} / gridSize
		n := deterministicValueNoise2d(f, 3)
		grid.data[i] = u8(math.step(cutoff, n))
	}
}
getGridHeight :: proc(grid: ^Grid) -> i32 {
	return i32(len(grid.data)) / grid.width
}
getGridIndexWorldPosition :: proc(grid: ^Grid, i: i32) -> rl.Vector2 {
	return {f32(i % grid.width) * grid.blockSize, f32(i / getGridHeight(grid)) * grid.blockSize}
}
debugDrawGrid :: proc(grid: ^Grid, pos: rl.Vector2, tint: rl.Color) {
	tex := getTexture(.White32)
	texSrc := getTextureRec(tex)
	texSize := rl.Vector2{texSrc.width, texSrc.height}
	for block, i in grid.data {
		if (block > 0) {
			worldPos := getGridIndexWorldPosition(grid, i32(i))
			texDest := rl.Rectangle{worldPos.x, worldPos.y, texSize.x, texSize.y}
			rl.DrawTexturePro(tex, texSrc, texDest, {0.0, 0.0}, 0.0, tint)
		}
	}
}

init :: proc() {
	loadTextures()
	initSpriteDefs()
	loadShaders()
}

deinit :: proc() {
	unloadTextures()
	unloadShaders()
}

main :: proc() {
	// Raylib init
	rl.SetConfigFlags({.WINDOW_RESIZABLE}) // TODO: Remove artifacts from main framebuffer
	rl.SetTraceLogLevel(.WARNING)
	rl.SetTargetFPS(TARGET_FPS)
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "ElevatorObject Game")
	defer rl.CloseWindow()

	// Engine init
	gameArena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&gameArena)
	defer mem.dynamic_arena_free_all(&gameArena)
	context.allocator = mem.dynamic_arena_allocator(&gameArena)

	frameArena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&frameArena)
	defer mem.dynamic_arena_free_all(&frameArena)
	context.temp_allocator = mem.dynamic_arena_allocator(&frameArena)

	init()
	defer deinit()
	gameRenderTex := rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	defer rl.UnloadRenderTexture(gameRenderTex)

	solidBlocks := make([dynamic]rl.Rectangle, context.allocator)
	globalSolidBlocks = &solidBlocks
	append(globalSolidBlocks, rl.Rectangle{0.0, 0.0, WINDOW_WIDTH, 16.0})
	append(globalSolidBlocks, rl.Rectangle{WINDOW_WIDTH - 16.0, 0.0, 16.0, WINDOW_HEIGHT})
	append(globalSolidBlocks, rl.Rectangle{0.0, WINDOW_HEIGHT - 16.0, WINDOW_WIDTH, 16.0})
	append(globalSolidBlocks, rl.Rectangle{0.0, 0.0, 16.0, WINDOW_HEIGHT})
	for i in 0 ..< 32 {
		pos := rl.Vector2{rand.float32() * WINDOW_WIDTH, rand.float32() * WINDOW_HEIGHT}
		append(globalSolidBlocks, rl.Rectangle{pos.x, pos.y, 32.0, 32.0})
	}

	gameMusic := loadMusicStream(.KowloonSmokeBreak)
	rl.PlayMusicStream(gameMusic)
	gameObjects := make([dynamic]GameObject, context.allocator)
	globalGameObjects = &gameObjects

	// Game init
	web10TexSize := rl.Vector2{128.0, 128.0}
	web10Tex := web10CreateTexture(
		cast(i32)web10TexSize.x,
		cast(i32)web10TexSize.y,
		getSpriteDef(.Star),
		16,
	)
	defer rl.UnloadTexture(web10Tex)
	repeatingStarBg := createRepeatingStarBg(
		getShader(.AnimatedTextureRepeatPosition),
		web10Tex,
		web10TexSize,
		4.0,
		7,
		rl.Vector2{30.0, 20.0},
	)

	elevator := createElevator(context.allocator, {128.0, 128.0})
	player := createPlayer(context.allocator, {64.0, 64.0})

	camera := rl.Camera2D {
		offset   = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		target   = player.object.pos,
		rotation = 0.0,
		zoom     = 1.0,
	}

	grid := createGrid(context.allocator, 32, 32, 16.0)
	fillGrid(&grid, {0.0, 0.0}, 0.5)

	mem.dynamic_arena_reset(&frameArena)

	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(gameMusic)
		if rl.IsMouseButtonPressed(.LEFT) {
			player.object.pos = rl.GetMousePosition()
		}
		zoom := getAppRtexZoom()
		camera.offset = {WINDOW_WIDTH * zoom / 2, WINDOW_HEIGHT * zoom / 2}
		camera.target = player.object.pos - getObjectCenter(player.object)
		camera.zoom = getAppRtexZoom()
		rl.BeginDrawing()
		rl.BeginMode2D(camera)
		rl.ClearBackground(rl.BLACK)
		drawRepeatingStarBg(&repeatingStarBg)
		for block in globalSolidBlocks {
			rl.DrawRectangleV({block.x, block.y}, {block.width, block.height}, rl.WHITE)
		}
		for object in gameObjects {
			object.update(object.data)
		}
		whiteTex := getTexture(.White32)
		whiteTexSrc := getTextureRec(whiteTex)
		for i in 0 ..< len(gameObjects) {
			rl.DrawTexturePro(
				whiteTex,
				whiteTexSrc,
				getObjAbsColRec(&gameObjects[i], {0.0, 0.0}),
				{0.0, 0.0},
				0.0,
				{0, 192, 0, 128},
			)
		}
		debugDrawGrid(&grid, {0.0, 0.0}, {0, 192, 0, 128})
		rl.EndMode2D()
		rl.EndDrawing()
		mem.dynamic_arena_reset(&frameArena)
	}
}
