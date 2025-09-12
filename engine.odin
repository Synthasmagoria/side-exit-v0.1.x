package game
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/noise"
import "core:mem"
import "core:reflect"
import "core:strings"
import rl "lib/raylib"
import rlgl "lib/raylib/rlgl"

Resources :: struct {
	models:     [ModelName._Count]rl.Model,
	music:      [MusicName._Count]rl.Music,
	textures:   [TextureName._Count]rl.Texture,
	spriteDefs: [TextureName._Count]SpriteDef,
}
resources: Resources

ModelName :: enum {
	Elevator,
	ElevatorSlidingDoorLeft,
	ElevatorSlidingDoorRight,
	_Count,
}
getModel :: proc(ind: ModelName) -> rl.Model {
	return resources.models[ind]
}
loadModels :: proc() {
	context.allocator = context.temp_allocator
	texNames := reflect.enum_field_names(ModelName)
	for name, i in texNames[0:len(texNames) - 1] {
		n := transmute([]u8)strings.clone(name, context.temp_allocator)
		n[0] = charLower(n[0])
		path := strings.join({"mod/", cast(string)n, ".glb"}, "", context.temp_allocator)
		resources.models[i] = rl.LoadModel(strings.clone_to_cstring(path, context.temp_allocator))
	}
}
unloadModels :: proc() {
	for model in resources.models {
		for i in 0 ..< model.materialCount {
			unloadMaterialNoMap(model.materials[i])
		}
		rl.UnloadModel(model)
	}
}

MusicName :: enum {
	KowloonSmokeBreak,
	_Count,
}
loadMusicStream :: proc(ind: MusicName) -> rl.Music {
	context.allocator = context.temp_allocator
	name, ok := reflect.enum_name_from_value(ind)
	_ = ok
	fileName := transmute([]byte)strings.clone(name)
	fileName[0] = charLower(fileName[0])
	filePath := [?]string{"aud/", cast(string)fileName, ".mp3"}
	joinedPath := strings.join(filePath[:], "")
	return rl.LoadMusicStream(strings.clone_to_cstring(joinedPath))
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
	ElevatorWall3D,
	InteractionIndicationArrow,
	_Count,
}
getTexture :: proc(ind: TextureName) -> rl.Texture {
	return resources.textures[ind]
}
loadTextures :: proc() {
	context.allocator = context.temp_allocator
	texNames := reflect.enum_field_names(TextureName)
	for name, i in texNames[0:len(texNames) - 1] {
		n := transmute([]u8)strings.clone(name, context.temp_allocator)
		n[0] = charLower(n[0])
		path := strings.join({"tex/", cast(string)n, ".png"}, "", context.temp_allocator)
		resources.textures[i] = rl.LoadTexture(
			strings.clone_to_cstring(path, context.temp_allocator),
		)
	}
}
unloadTextures :: proc() {
	for t in resources.textures {
		rl.UnloadTexture(t)
	}
}

getSpriteDef :: proc(ind: TextureName) -> SpriteDef {
	return resources.spriteDefs[ind]
}
_setSpriteDef :: proc(
	ind: TextureName,
	frame_width: i32,
	frame_spd: f32,
	origin: rl.Vector2 = {0.0, 0.0},
) {
	resources.spriteDefs[ind] = createSpriteDef(getTexture(ind), frame_width, frame_spd, origin)
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
	Lighting3D,
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
		n := transmute([]u8)strings.clone(name)
		n[0] = charLower(n[0])
		vertPath := [?]string{"shd/", cast(string)n, ".vert"}
		fragPath := [?]string{"shd/", cast(string)n, ".frag"}
		globalShaders[i] = rl.LoadShader(
			strings.clone_to_cstring(strings.join(vertPath[:], "")),
			strings.clone_to_cstring(strings.join(fragPath[:], "")),
		)
	}
}
unloadShaders :: proc() {
	for shd in globalShaders {
		rl.UnloadShader(shd)
	}
}

Light3D :: struct {
	enabled:  c.int,
	type:     LightType,
	position: rl.Vector3,
	target:   rl.Vector3,
	color:    rl.Vector4,
}

LightType :: enum c.int {
	Directional,
	Point,
}
MAX_LIGHTS :: 4
// TODO: Possibly optimizable with constant locations by using a shader include system
applyLightToShader :: proc(shd: rl.Shader) {
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "ambient"),
		&global.ambientLightingColor,
		.VEC4,
	)
	rl.SetShaderValue(shd, rl.GetShaderLocation(shd, "viewPos"), &global.camera3D.position, .VEC3)

	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[0].enabled"),
		&global.lights3D[0].enabled,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[0].type"),
		&global.lights3D[0].type,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[0].position"),
		&global.lights3D[0].position,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[0].target"),
		&global.lights3D[0].target,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[0].color"),
		&global.lights3D[0].color,
		.VEC4,
	)

	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[1].enabled"),
		&global.lights3D[1].enabled,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[1].type"),
		&global.lights3D[1].type,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[1].position"),
		&global.lights3D[1].position,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[1].target"),
		&global.lights3D[1].target,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[1].color"),
		&global.lights3D[1].color,
		.VEC4,
	)

	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[2].enabled"),
		&global.lights3D[2].enabled,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[2].type"),
		&global.lights3D[2].type,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[2].position"),
		&global.lights3D[2].position,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[2].target"),
		&global.lights3D[2].target,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[2].color"),
		&global.lights3D[2].color,
		.VEC4,
	)

	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[3].enabled"),
		&global.lights3D[3].enabled,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[3].type"),
		&global.lights3D[3].type,
		.INT,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[3].position"),
		&global.lights3D[3].position,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[3].target"),
		&global.lights3D[3].target,
		.VEC3,
	)
	rl.SetShaderValue(
		shd,
		rl.GetShaderLocation(shd, "lights[3].color"),
		&global.lights3D[3].color,
		.VEC4,
	)
}

GameObject :: struct {
	startProc:   proc(data: rawptr),
	updateProc:  proc(data: rawptr),
	drawProc:    proc(data: rawptr),
	drawEndProc: proc(data: rawptr),
	destroyProc: proc(data: rawptr),
	data:        rawptr,
	pos:         rl.Vector2,
	colRec:      rl.Rectangle,
	id:          i32,
	type:        typeid,
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
	drawEndProc: proc(_: rawptr) = gameObjectEmptyProc,
	destroyProc: proc(_: rawptr) = gameObjectEmptyProc,
) -> ^GameObject {
	object := GameObject {
		startProc   = startProc,
		updateProc  = updateProc,
		drawProc    = drawProc,
		drawEndProc = drawEndProc,
		destroyProc = destroyProc,
		data        = data,
		id          = globalGameObjectIdCounter,
		type        = T,
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
getGameObjectScreenPos :: proc(obj: ^GameObject) -> rl.Vector2 {
	return obj.pos - global.camera.target + global.camera.offset
}
getFirstGameObjectOfType :: proc($T: typeid) -> ^T {
	for i in 0 ..< len(globalGameObjects) {
		if globalGameObjects[i].type == T {
			return cast(^T)globalGameObjects[i].data
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
getObjCenterAbs :: proc(object: GameObject) -> rl.Vector2 {
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

LOADED_CHUNK_SIZE :: 3
LOADED_CHUNK_COUNT :: LOADED_CHUNK_SIZE * LOADED_CHUNK_SIZE
CHUNK_BLOCK_WIDTH :: 16
CHUNK_BLOCK_WIDTH_PX :: 16
CHUNK_BLOCK_COUNT :: CHUNK_BLOCK_WIDTH * CHUNK_BLOCK_WIDTH
CHUNK_WIDTH_PX :: CHUNK_BLOCK_WIDTH * CHUNK_BLOCK_WIDTH_PX
ChunkDataMatrix :: [LOADED_CHUNK_COUNT][CHUNK_BLOCK_COUNT]byte
ChunkDataRecs :: [LOADED_CHUNK_COUNT][dynamic]rl.Rectangle

ChunkWorld :: struct {
	data:      ChunkDataMatrix,
	rects:     ChunkDataRecs,
	genCutoff: f32,
	pos:       iVector2,
}
chunkWorldCalcPos :: proc(target: GameObject) -> iVector2 {
	targetCenter := getObjCenterAbs(target)
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
				msg := strings.join(msgStrs[:], "", context.temp_allocator)
				fmt.println(msg)
				continue
			}
			matPosNew := iVector2{matPos.x + diff.x, matPos.y + diff.y}
			if !pointInIrec(matPosNew, matRec) {
				posStr := fmt.tprintf("%v", matPosNew)
				msgStrs := [?]string{"error (moveChunks): Invalid new position", posStr}
				msg := strings.join(msgStrs[:], "", context.temp_allocator)
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
			iVector2{i32(i) % LOADED_CHUNK_SIZE, i32(i) / LOADED_CHUNK_SIZE} +
			global.chunkWorld.pos
		matrixWorldRec := rl.Rectangle {
			f32(pos.x * CHUNK_WIDTH_PX),
			f32(pos.y * CHUNK_WIDTH_PX),
			CHUNK_WIDTH_PX,
			CHUNK_WIDTH_PX,
		}
		if recInRec(rec, matrixWorldRec) {
			for solidRec in global.chunkWorld.rects[i] {
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

TweenF32Range :: struct {
	from: f32,
	to:   f32,
}
TweenI32Range :: struct {
	from: i32,
	to:   i32,
}
TweenU8Range :: struct {
	from: u8,
	to:   u8,
}
TweenVector2Range :: struct {
	from: rl.Vector2,
	to:   rl.Vector2,
}
TweenVector3Range :: struct {
	from: rl.Vector3,
	to:   rl.Vector3,
}
TweenRange :: union #no_nil {
	TweenF32Range,
	TweenI32Range,
	TweenU8Range,
	TweenVector2Range,
	TweenVector3Range,
}
TweenValue :: union #no_nil {
	f32,
	i32,
	u8,
	rl.Vector2,
	rl.Vector3,
}
TweenCurve :: enum {
	Linear,
	Exp,
	InvExp,
	Hermite,
}

Tween :: struct {
	range: TweenRange,
	curve: TweenCurve,
	t:     f32,
	dur:   f32,
	delay: f32,
}
createTween :: proc(range: TweenRange, curve: TweenCurve, dur: f32, delay: f32 = 0.0) -> Tween {
	assert(dur > 0.0, "Tween duration cannot equal to or less than 0.0")
	assert(delay >= 0.0, "Tween delay cannot be less than 0.0")
	return {range = range, curve = curve, t = 0.0, dur = dur, delay = delay}
}
updateAndStepTween :: proc(tween: ^Tween) -> TweenValue {
	tween.t = math.min(tween.t + TARGET_TIME_STEP, tween.dur + tween.delay)
	active_t := math.max(0.0, tween.t - tween.delay)
	progress: f32
	switch tween.curve {
	case .Linear:
		progress = active_t / tween.dur
	case .Exp:
		progress = math.pow(active_t / tween.dur, 2)
	case .InvExp:
		progress = 1.0 - math.pow((tween.dur - active_t) / tween.dur, 2)
	case .Hermite:
		progress = math.smoothstep(f32(0.0), f32(1.0), active_t / tween.dur)
	}
	switch range in tween.range {
	case TweenF32Range:
		return math.lerp(range.from, range.to, progress)
	case TweenI32Range:
		return i32(math.lerp(f32(range.from), f32(range.to), progress))
	case TweenVector2Range:
		return math.lerp(range.from, range.to, progress)
	case TweenVector3Range:
		return math.lerp(range.from, range.to, progress)
	case TweenU8Range:
		return u8(math.lerp(f32(range.from), f32(range.to), progress))
	}
	panic("Unreachable, invalid tween type")
}
tweenIsFinished :: proc(tween: Tween) -> bool {
	return tween.t == tween.dur + tween.delay
}
tweenIsWaiting :: proc(tween: Tween) -> bool {
	return tween.t <= tween.delay
}
finishTween :: proc(tween: ^Tween) {
	tween.t = tween.dur + tween.delay
}
createFinishedTween :: proc(range: TweenRange) -> Tween {
	return {range = range, curve = .Linear, dur = 1.0, t = 1.0, delay = 0.0}
}
