package game

import "core:fmt"
import math "core:math"
import linalg "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/noise"
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
		n := transmute([]u8)string_util.clone(name, context.temp_allocator)
		n[0] = charLower(n[0])
		path := string_util.join({"tex/", cast(string)n, ".png"}, "", context.temp_allocator)
		globalTextures[i] = rl.LoadTexture(
			string_util.clone_to_cstring(path, context.temp_allocator),
		)
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
_setSpriteDef :: proc(
	ind: TextureName,
	frame_width: i32,
	frame_spd: f32,
	origin: rl.Vector2 = {0.0, 0.0},
) {
	globalSpriteDefs[ind] = createSpriteDef(getTexture(ind), frame_width, frame_spd, origin)
}
initSpriteDefs :: proc() {
	_setSpriteDef(.Star, 4, 8.0)
	_setSpriteDef(.SynthIdle, 24, 8.0)
	_setSpriteDef(.SynthIdleBack, 24, 8.0)
	_setSpriteDef(.SynthWalk, 24, 8.0)
	_setSpriteDef(.SynthWalkBack, 24, 8.0)
	_setSpriteDef(.InteractionIndicationArrow, 14, 8.0, {7.0, 7.0})
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
	startProc:  proc(data: rawptr),
	updateProc: proc(data: rawptr),
	drawProc:   proc(data: rawptr),
	guiProc:    proc(data: rawptr),
	data:       rawptr,
	pos:        rl.Vector2,
	colRec:     rl.Rectangle,
	id:         i32,
	type:       typeid,
}
GameObjectFuncs :: struct {}
globalGameObjects: ^[dynamic]GameObject = nil
globalGameObjectIdCounter: i32 = min(i32)
gameObjectEmptyProc :: proc(_: rawptr) {}
createGameObject :: proc(
	$T: typeid,
	data: rawptr,
	startProc: proc(_: rawptr) = gameObjectEmptyProc,
	updateProc: proc(_: rawptr) = gameObjectEmptyProc,
	drawProc: proc(_: rawptr) = gameObjectEmptyProc,
	guiProc: proc(_: rawptr) = gameObjectEmptyProc,
) -> ^GameObject {
	object := GameObject {
		startProc  = startProc,
		updateProc = updateProc,
		drawProc   = drawProc,
		guiProc    = guiProc,
		data       = data,
		id         = globalGameObjectIdCounter,
		type       = T,
	}
	append(globalGameObjects, object)
	globalGameObjectIdCounter += 1
	return &globalGameObjects[len(globalGameObjects) - 1]
}
setGameObjectStartFunc :: proc()
getGameObjectsOfType :: proc(type: typeid) -> [dynamic]^GameObject {
	context.allocator = context.temp_allocator
	objs := make([dynamic]^GameObject, 0, 10)
	for i in 0 ..< len(globalGameObjects) {
		if globalGameObjects[i].type == type {
			append(&objs, &globalGameObjects[i])
		}
	}
	return objs
}
getFirstGameObjectOfType :: proc(type: typeid) -> ^GameObject {
	for i in 0 ..< len(globalGameObjects) {
		if globalGameObjects[i].type == type {
			return &globalGameObjects[i]
		}
	}
	return nil
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
getObjCenter :: proc(object: GameObject) -> rl.Vector2 {
	return {
		object.colRec.x + object.colRec.width / 2.0,
		object.colRec.y + object.colRec.height / 2.0,
	}
}
getObjCenterPosition :: proc(object: GameObject) -> rl.Vector2 {
	return {
		object.colRec.x + object.colRec.width / 2.0 + object.pos.x,
		object.colRec.y + object.colRec.height / 2.0 + object.pos.y,
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
debugDrawGameObjectCollisions :: proc() {
	whiteTex := getTexture(.White32)
	whiteTexSrc := getTextureRec(whiteTex)
	for i in 0 ..< len(globalGameObjects) {
		rl.DrawTexturePro(
			whiteTex,
			whiteTexSrc,
			getObjAbsColRec(&globalGameObjects[i], {0.0, 0.0}),
			{0.0, 0.0},
			0.0,
			{0, 192, 0, 128},
		)
	}
}

SpriteDef :: struct {
	tex:         rl.Texture,
	frame_count: i32,
	frame_width: i32,
	frame_spd:   f32,
	origin:      rl.Vector2,
}
createSpriteDef :: proc(
	tex: rl.Texture,
	frame_width: i32,
	frame_spd: f32,
	origin := rl.Vector2{0.0, 0.0},
) -> SpriteDef {
	return {
		tex = tex,
		frame_count = tex.width / frame_width,
		frame_width = frame_width,
		frame_spd = frame_spd,
		origin = origin,
	}
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
	offX: i32 = scaleSign == 1.0 ? 0 : spr.def.frame_width
	return {
		cast(f32)(spr.frame_ind * spr.def.frame_width + offX),
		0.0,
		cast(f32)spr.def.frame_width * scaleSign,
		cast(f32)spr.def.tex.height,
	}
}
drawSpriteEx :: proc(spr: Sprite, pos: rl.Vector2, scale: rl.Vector2) {
	src := getSpriteSourceRect(spr, scale)
	frame_width := f32(spr.def.frame_width)
	size := rl.Vector2{frame_width, frame_width} * scale
	dest := rl.Rectangle{pos.x - spr.def.origin.x, pos.y - spr.def.origin.y, size.x, size.y}
	rl.DrawTexturePro(spr.def.tex, src, dest, {0.0, 0.0}, 0.0, rl.WHITE)
}
drawSpriteRect :: proc(spr: Sprite, dest: rl.Rectangle) {
	src := getSpriteSourceRect(spr, {1.0, 1.0})
	frame_width := f32(spr.def.tex.width)
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
pointInIrec :: proc(point: iVector2, rectangle: iRectangle) -> bool {
	return(
		point.x >= rectangle.x &&
		point.x < rectangle.x + rectangle.width &&
		point.y >= rectangle.y &&
		point.y < rectangle.y + rectangle.height \
	)
}

iVector2 :: [2]i32
iRectangle :: struct {
	x:      i32,
	y:      i32,
	width:  i32,
	height: i32,
}
iRectangleClampVal :: proc(irec: iRectangle, a: i32, b: i32) -> iRectangle {
	x2 := irec.x + irec.width
	y2 := irec.y + irec.height
	xClamped := math.clamp(irec.x, a, b)
	yClamped := math.clamp(irec.y, a, b)
	widthClamped := math.clamp(x2, a, b + 1) - xClamped
	heightClamped := math.clamp(y2, a, b + 1) - yClamped
	return {xClamped, yClamped, widthClamped, heightClamped}
}
iRectangleAssertInv :: proc(irec: iRectangle) {
	assert_contextless(irec.x <= irec.x + irec.width && irec.y <= irec.y + irec.height)
}
iRectangleGetInd :: proc(irec: iRectangle, maxWidth: i32) -> i32 {
	return irec.x + irec.height * maxWidth
}

LOADED_CHUNK_SIZE :: 3
LOADED_CHUNK_COUNT :: LOADED_CHUNK_SIZE * LOADED_CHUNK_SIZE
CHUNK_BLOCK_WIDTH :: 16
CHUNK_BLOCK_WIDTH_PX :: 16
CHUNK_BLOCK_COUNT :: CHUNK_BLOCK_WIDTH * CHUNK_BLOCK_WIDTH
CHUNK_WIDTH_PX :: CHUNK_BLOCK_WIDTH * CHUNK_BLOCK_WIDTH_PX
ChunkDataMatrix :: [LOADED_CHUNK_COUNT][CHUNK_BLOCK_COUNT]byte
ChunkDataRecs :: [LOADED_CHUNK_COUNT][dynamic]rl.Rectangle
globalChunkWorld: ^ChunkWorld

ChunkWorld :: struct {
	data:      ChunkDataMatrix,
	rects:     ChunkDataRecs,
	genCutoff: f32,
	pos:       iVector2,
}
chunkWorldCalcPos :: proc(target: GameObject) -> iVector2 {
	targetCenter := getObjCenterPosition(target)
	return iVector2 {
		i32(math.floor((targetCenter.x - CHUNK_WIDTH_PX) / CHUNK_WIDTH_PX)),
		i32(math.floor((targetCenter.y - CHUNK_WIDTH_PX) / CHUNK_WIDTH_PX)),
	}
}
updateChunkWorld :: proc(chunkWorld: ^ChunkWorld, target: GameObject) {
	newPos := chunkWorldCalcPos(target)
	if (newPos.x != chunkWorld.pos.x || newPos.y != chunkWorld.pos.y) {
		diffX := newPos.x - chunkWorld.pos.x
		unloadableChunks: [LOADED_CHUNK_COUNT]byte
		if diffX < 0 {
			unloadArea := iRectangleClampVal(
				{LOADED_CHUNK_SIZE + diffX, 0, math.abs(diffX), LOADED_CHUNK_SIZE},
				0,
				LOADED_CHUNK_SIZE - 1,
			)
			unloadableChunks = chunkBitmaskOrRec(unloadableChunks, unloadArea)
		} else if diffX > 0 {
			unloadArea := iRectangleClampVal(
				iRectangle{0, 0, diffX, LOADED_CHUNK_SIZE},
				0,
				LOADED_CHUNK_SIZE - 1,
			)
			unloadableChunks = chunkBitmaskOrRec(unloadableChunks, unloadArea)
		}

		diffY := newPos.y - chunkWorld.pos.y
		if diffY < 0 {
			unloadArea := iRectangleClampVal(
				{0, LOADED_CHUNK_SIZE + diffY, LOADED_CHUNK_SIZE, math.abs(diffY)},
				0,
				LOADED_CHUNK_SIZE - 1,
			)
			unloadableChunks = chunkBitmaskOrRec(unloadableChunks, unloadArea)
		} else if diffY > 0 {
			unloadArea := iRectangleClampVal(
				{0, 0, LOADED_CHUNK_SIZE, diffY},
				0,
				LOADED_CHUNK_SIZE - 1,
			)
			unloadableChunks = chunkBitmaskOrRec(unloadableChunks, unloadArea)
		}

		moveChunks(chunkWorld, chunkBitmaskNot(unloadableChunks), {-diffX, -diffY})
		chunkWorld.pos.x = newPos.x
		chunkWorld.pos.y = newPos.y
		regenerateChunks(chunkWorld, chunkBitmaskMirror(unloadableChunks))
	}
}
moveChunks :: proc(chunkWorld: ^ChunkWorld, chunkBitmask: ChunkBitmask, diff: iVector2) {
	chunkDataMatrix: ChunkDataMatrix
	chunkDataRecs: ChunkDataRecs
	for i in 0 ..< len(chunkDataMatrix) {
		if chunkBitmask[i] > 0 {
			matPos := iVector2{i32(i) % LOADED_CHUNK_SIZE, i32(i) / LOADED_CHUNK_SIZE}
			matRec := iRectangle{0, 0, LOADED_CHUNK_SIZE, LOADED_CHUNK_SIZE}
			// TODO: Create error printing func
			if !pointInIrec(matPos, matRec) {
				posStr := fmt.tprintf("%v", matPos)
				msgStrs := [?]string{"error (moveChunks): Invalid position ", posStr}
				msg := string_util.join(msgStrs[:], "", context.temp_allocator)
				fmt.println(msg)
				continue
			}
			matPosNew := iVector2{matPos.x + diff.x, matPos.y + diff.y}
			if !pointInIrec(matPosNew, matRec) {
				posStr := fmt.tprintf("%v", matPosNew)
				msgStrs := [?]string{"error (moveChunks): Invalid new position", posStr}
				msg := string_util.join(msgStrs[:], "", context.temp_allocator)
				fmt.println(msg)
				continue
			}
			newInd := getChunkWorldInd(matPosNew.x, matPosNew.y)
			mem.copy(&chunkDataMatrix[newInd], &chunkWorld.data[i], CHUNK_BLOCK_COUNT)
			chunkDataRecs[newInd] = chunkWorld.rects[i]
		}
		free(&chunkWorld.rects[i])
	}
	chunkWorld.data = chunkDataMatrix
	chunkWorld.rects = chunkDataRecs
}
regenerateChunks :: proc(chunkWorld: ^ChunkWorld, bitmask: ChunkBitmask) {
	for val, i in bitmask {
		if val > 0 {
			regenerateChunk(chunkWorld, i32(i))
		}
	}
}
regenerateChunkWorld :: proc(chunkWorld: ^ChunkWorld) {
	for i in 0 ..< LOADED_CHUNK_COUNT {
		regenerateChunk(chunkWorld, i32(i))
	}
}
regenerateChunk :: proc(chunkWorld: ^ChunkWorld, chunkIndex: i32) {
	clear(&chunkWorld.rects[chunkIndex])
	chunkPos :=
		iVector2{chunkIndex % LOADED_CHUNK_SIZE, chunkIndex / LOADED_CHUNK_SIZE} + chunkWorld.pos
	chunkWorldPosition := rl.Vector2 {
		f32(chunkPos.x * CHUNK_WIDTH_PX),
		f32(chunkPos.y * CHUNK_WIDTH_PX),
	}
	for i in 0 ..< CHUNK_BLOCK_COUNT {
		x := i % CHUNK_BLOCK_WIDTH
		y := i / CHUNK_BLOCK_WIDTH
		xf := f32(x + 1 + CHUNK_BLOCK_WIDTH * int(chunkPos.x))
		yf := f32(y + 1 + CHUNK_BLOCK_WIDTH * int(chunkPos.y))
		f := rl.Vector2{xf, yf} / rl.Vector2{CHUNK_BLOCK_WIDTH, CHUNK_BLOCK_WIDTH}
		n := noise.noise_2d(0, {f64(f.x), f64(f.y)})
		val := u8(math.step(chunkWorld.genCutoff, n))
		chunkWorld.data[chunkIndex][i] = val
		if val > 0 {
			rect := rl.Rectangle {
				chunkWorldPosition.x + f32(x * CHUNK_BLOCK_WIDTH_PX),
				chunkWorldPosition.y + f32(y * CHUNK_BLOCK_WIDTH_PX),
				CHUNK_BLOCK_WIDTH_PX,
				CHUNK_BLOCK_WIDTH_PX,
			}
			append(&chunkWorld.rects[chunkIndex], rect)
		}
	}
}
getChunkWorldInd :: proc(x: i32, y: i32) -> i32 {
	assert_contextless(x >= 0 && x < LOADED_CHUNK_COUNT && y >= 0 && y < LOADED_CHUNK_COUNT)
	return x + y * LOADED_CHUNK_SIZE
}
ChunkBitmask :: [LOADED_CHUNK_COUNT]byte
chunkBitmaskOrRec :: proc(a: ChunkBitmask, irec: iRectangle) -> ChunkBitmask {
	iRectangleAssertInv(irec)
	out := a
	clampedRec := iRectangleClampVal(irec, 0, 2)
	// TODO: Or bits instead of looping
	for x in irec.x ..< irec.x + irec.width {
		for y in irec.y ..< irec.y + irec.height {
			i := getChunkWorldInd(x, y)
			out[i] = 1
		}
	}
	return out
}
chunkBitmaskNot :: proc(val: ChunkBitmask) -> ChunkBitmask {
	newVal := val
	for i in 0 ..< len(val) {
		newVal[i] ~= 1
	}
	return newVal
}
chunkBitmaskMirror :: proc(val: ChunkBitmask) -> ChunkBitmask {
	newVal := val
	for i in 0 ..< len(val) {
		newVal[len(val) - 1 - i] = val[i]
	}
	return newVal
}
ChunkCollisionResult :: union {
	rl.Rectangle,
}
chunkCollision :: proc(rec: rl.Rectangle) -> ChunkCollisionResult {
	bitmask: ChunkBitmask
	for i in 0 ..< len(bitmask) {
		pos :=
			iVector2{i32(i) % LOADED_CHUNK_SIZE, i32(i) / LOADED_CHUNK_SIZE} + globalChunkWorld.pos
		matrixWorldRec := rl.Rectangle {
			f32(pos.x * CHUNK_WIDTH_PX),
			f32(pos.y * CHUNK_WIDTH_PX),
			CHUNK_WIDTH_PX,
			CHUNK_WIDTH_PX,
		}
		if recInRec(rec, matrixWorldRec) {
			for solidRec in globalChunkWorld.rects[i] {
				if recInRec(rec, solidRec) {
					return solidRec
				}
			}
		}
	}
	return nil
}
drawChunkWorld :: proc(chunkWorld: ^ChunkWorld) {
	tex := getTexture(.White32)
	texSrc := getTextureRec(tex)
	for i in 0 ..< LOADED_CHUNK_COUNT {
		x := i32(i % LOADED_CHUNK_SIZE)
		y := i32(i / LOADED_CHUNK_SIZE)
		dx := (chunkWorld.pos.x + x) * CHUNK_WIDTH_PX
		dy := (chunkWorld.pos.y + y) * CHUNK_WIDTH_PX
		for val, j in chunkWorld.data[i] {
			if val > 0 {
				xx := i32(j % CHUNK_BLOCK_WIDTH)
				yy := i32(j / CHUNK_BLOCK_WIDTH)
				texDest := rl.Rectangle {
					f32(dx + xx * CHUNK_BLOCK_WIDTH_PX),
					f32(dy + yy * CHUNK_BLOCK_WIDTH_PX),
					CHUNK_BLOCK_WIDTH_PX,
					CHUNK_BLOCK_WIDTH_PX,
				}
				rl.DrawTexturePro(getTexture(.White32), texSrc, texDest, {0.0, 0.0}, 0.0, rl.WHITE)
			}
		}
	}
}

updateCamera :: proc(target: GameObject) {
	zoom := getAppRtexZoom()
	camera.offset = {WINDOW_WIDTH * zoom / 2, WINDOW_HEIGHT * zoom / 2}
	camera.target = target.pos - getObjCenter(target)
	camera.zoom = getAppRtexZoom()
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

camera: rl.Camera2D

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

	chunkWorld := ChunkWorld {
		pos       = {-1, -1},
		genCutoff = 0.5,
	}
	globalChunkWorld = &chunkWorld
	regenerateChunkWorld(&chunkWorld)

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
	//_ = createElevatorObjectPanel(context.allocator, {0.0, 0.0})

	camera = rl.Camera2D {
		offset   = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		target   = player.object.pos,
		rotation = 0.0,
		zoom     = 1.0,
	}

	mem.dynamic_arena_reset(&frameArena)

	for object in globalGameObjects {
		object.startProc(object.data)
	}
	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(gameMusic)
		if rl.IsMouseButtonPressed(.LEFT) {
			player.object.pos = rl.GetMousePosition()
		}
		updateCamera(player.object^)
		updateChunkWorld(&chunkWorld, player.object^)
		rl.BeginDrawing()
		rl.BeginMode2D(camera)
		rl.ClearBackground(rl.BLACK)
		drawRepeatingStarBg(&repeatingStarBg)
		drawChunkWorld(&chunkWorld)
		for object in globalGameObjects {
			object.updateProc(object.data)
		}
		for object in globalGameObjects {
			object.drawProc(object.data)
		}
		rl.EndMode2D()
		for object in globalGameObjects {
			object.guiProc(object.data)
		}
		rl.EndDrawing()
		mem.dynamic_arena_reset(&frameArena)
	}
}
