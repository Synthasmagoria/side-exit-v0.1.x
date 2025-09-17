package game
import "core:c"
import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/noise"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:reflect"
import "core:strings"
import rl "lib/raylib"
import rlgl "lib/raylib/rlgl"

raylibFree :: libc.free
raylibMalloc :: libc.malloc
raylibCalloc :: libc.calloc
raylibRealloc :: libc.realloc

initEngine :: proc() {
	initEngineMemory()
	en := engine
	engine.renderTexture = rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	engine.collisionRectangles = make([dynamic]iRectangle, 0, 1000, engine.gameAlloc)
	engine.renderTextureStack = make([dynamic]rl.RenderTexture, 0, 5, engine.gameAlloc)
	engine.gameObjects = make([dynamic]GameObject, 0, 100, engine.gameAlloc)
	engine.gameObjectsDepthOrdered = make([dynamic]^GameObject, 0, 100, engine.gameAlloc)
	engine.gameObjectIdCounter = min(i32)
}

deinitEngine :: proc() {
	unloadMaterialMapOnly(engine.defaultMaterial3D)
	deinitEngineMemory()
}

initEngineMemory :: proc() {
	// TODO: Debug switch on this
	mem.dynamic_arena_init(&engine.gameArena)
	defer mem.dynamic_arena_free_all(&engine.gameArena)
	engine.gameAlloc = mem.Allocator {
		data      = &engine.gameArena,
		procedure = dynamicArenaAllocatorDebugProc_Game,
	} //mem.dynamic_arena_allocator(&engine.gameArena)

	mem.dynamic_arena_init(&engine.levelArena)
	defer mem.dynamic_arena_free_all(&engine.levelArena)
	engine.levelAlloc = mem.Allocator {
		data      = &engine.levelArena,
		procedure = dynamicArenaAllocatorDebugProc_Level,
	} //mem.dynamic_arena_allocator(&engine.levelArena)

	mem.dynamic_arena_init(&engine.frameArena)
	defer mem.dynamic_arena_free_all(&engine.frameArena)
	engine.frameAlloc = mem.dynamic_arena_allocator(&engine.frameArena)
}

deinitEngineMemory :: proc() {
	mem.dynamic_arena_destroy(&engine.gameArena)
	mem.dynamic_arena_destroy(&engine.levelArena)
	mem.dynamic_arena_destroy(&engine.frameArena)
}

engine: Engine
Engine :: struct {
	frameArena:              mem.Dynamic_Arena,
	frameAlloc:              mem.Allocator,
	levelArena:              mem.Dynamic_Arena,
	levelAlloc:              mem.Allocator,
	gameArena:               mem.Dynamic_Arena,
	gameAlloc:               mem.Allocator,
	gameRenderTexture:       rl.RenderTexture,
	currentRenderTexture:    Maybe(rl.RenderTexture),
	renderTextureStack:      [dynamic]rl.RenderTexture,
	gameObjects:             [dynamic]GameObject,
	gameObjectsDepthOrdered: [dynamic]^GameObject,
	gameObjectIdCounter:     i32,
	lights3D:                [MAX_LIGHTS]Light3D,
	collisionRectangles:     [dynamic]iRectangle,
	defaultMaterial3D:       rl.Material,
	renderTexture:           rl.RenderTexture,
	ambientLightingColor:    rl.Vector4,
}

Resources :: struct {
	models:     [ModelName._Count]rl.Model,
	music:      [MusicName._Count]rl.Music,
	textures:   [TextureName._Count]rl.Texture,
	spriteDefs: [TextureName._Count]SpriteDef,
	sounds:     [SoundName._Count]rl.Sound,
}
resources: Resources

SoundName :: enum {
	ElevatorArrive,
	ElevatorArrive2,
	PlayerJump,
	PlayerAirJump,
	ElevatorDoor1,
	ElevatorDoor2,
	ElevatorDoor3,
	ElevatorPanelButton,
	ElevatorPanelKnob1,
	ElevatorPanelKnob2,
	ElevatorPanelKnob3,
	ElevatorPanelSlider,
	_Count,
}
getSound :: proc(ind: SoundName) -> rl.Sound {
	return resources.sounds[ind]
}
loadSounds :: proc() {
	context.allocator = context.temp_allocator
	soundNames := reflect.enum_field_names(SoundName)
	for name, i in soundNames[0:int(SoundName._Count) - 1] {
		n := transmute([]u8)strings.clone(name)
		n[0] = charLower(n[0])
		path := strings.join({"sfx/", cast(string)n, ".wav"}, "", context.temp_allocator)
		resources.sounds[i] = rl.LoadSound(strings.clone_to_cstring(path))
	}
}
unloadSounds :: proc() {
	for sound in resources.sounds {
		rl.UnloadSound(sound)
	}
}

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
	ElevatorPanelButton,
	ElevatorPanelKnob,
	ElevatorPanelSlider,
	ElevatorPanelBigButtons,
	ElevatorWall3D,
	ElevatorLights3D,
	InteractionIndicationArrow,
	HubBackground,
	HubBuilding,
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
	_setSpriteDef(.ElevatorPanelButton, 21, 1.0)
}

ShaderNames :: enum {
	AnimatedTextureRepeatPosition,
	Passthrough3D,
	AnimatedTexture3D,
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
		if shader := loadAndResolveShader(name); shader != nil {
			globalShaders[i] = shader.?
		} else {
			panic("Couldn't load shader")
		}
		// n := transmute([]u8)strings.clone(name)
		// n[0] = charLower(n[0])
		// vertPath := [?]string{"shd/", cast(string)n, ".vert"}
		// fragPath := [?]string{"shd/", cast(string)n, ".frag"}
		// globalShaders[i] = rl.LoadShader(
		// 	strings.clone_to_cstring(strings.join(vertPath[:], "")),
		// 	strings.clone_to_cstring(strings.join(fragPath[:], "")),
		// )
	}
}
unloadShaders :: proc() {
	for shd in globalShaders {
		rl.UnloadShader(shd)
	}
}
loadAndResolveShader :: proc(name: string) -> Maybe(rl.Shader) {
	dir := "shd/"
	context.allocator = context.temp_allocator
	shaderNameLower := transmute([]u8)strings.clone(name)
	shaderNameLower[0] = charLower(shaderNameLower[0])
	vertPathParts := [?]string{dir, cast(string)shaderNameLower, ".vert"}
	fragPathParts := [?]string{dir, cast(string)shaderNameLower, ".frag"}
	vertPath := strings.join(vertPathParts[:], "")
	fragPath := strings.join(fragPathParts[:], "")

	vertCodeBytes, vertFileReadSuccess := os.read_entire_file(vertPath)
	if !vertFileReadSuccess {
		msgParts := [?]string{"Couldn't read vertex shader at '", vertPath, "'"}
		rl.TraceLog(.WARNING, strings.clone_to_cstring(strings.join(msgParts[:], "")))
		return nil
	}

	fragCodeBytes, fragCodeReadSuccess := os.read_entire_file(fragPath)
	if !fragCodeReadSuccess {
		msgParts := [?]string{"Coultn't read fragment shader at '", fragPath, "'"}
		rl.TraceLog(.WARNING, strings.clone_to_cstring(strings.join(msgParts[:], "")))
		return nil
	}

	vertCodeResolved, vertResolveError := resolveShaderIncludes(
		strings.clone_from(vertCodeBytes),
		dir,
	)
	if vertResolveError != .None {
		traceLogShaderIncludeError(vertResolveError)
		return nil
	}
	fragCodeResolved, fragResolveError := resolveShaderIncludes(
		strings.clone_from(fragCodeBytes),
		dir,
	)
	if fragResolveError != .None {
		traceLogShaderIncludeError(fragResolveError)
		return nil
	}
	return rl.LoadShaderFromMemory(
		strings.clone_to_cstring(vertCodeResolved),
		strings.clone_to_cstring(fragCodeResolved),
	)
}
ResolveShaderIncludesError :: enum {
	None,
	MissingOpeningQuote,
	MissingClosingQuote,
	FileEndsAfterClosingIncludeQuote,
	CouldntReadIncludeFile,
	DoesntSupportNestedInclude,
}
resolveShaderIncludes :: proc(
	shdStr: string,
	dir: string,
) -> (
	string,
	ResolveShaderIncludesError,
) {
	includelessCodeSlices := make([dynamic]string, 0, 10)
	if strings.contains(shdStr, "#include") {
		vertCodeLoopSlice := shdStr[:]
		for i := strings.index(vertCodeLoopSlice, "#include");
		    i != -1;
		    i = strings.index(vertCodeLoopSlice, "#include") {
			append(&includelessCodeSlices, vertCodeLoopSlice[:i])
			vertCodeLoopSlice = vertCodeLoopSlice[i:]
			openingQuote := strings.index_byte(vertCodeLoopSlice, '\"')
			if openingQuote == -1 {
				return shdStr, .MissingOpeningQuote
			}
			closingQuote := strings.index_byte(vertCodeLoopSlice[openingQuote + 1:], '\"')
			if closingQuote == -1 {
				return shdStr, .MissingClosingQuote
			}
			closingQuote += openingQuote
			if closingQuote + 1 >= len(vertCodeLoopSlice) {
				return shdStr, .FileEndsAfterClosingIncludeQuote
			}
			includePathParts := [?]string {
				dir,
				vertCodeLoopSlice[openingQuote + 1:closingQuote + 1],
			}

			includeCodeBytes, includeCodeReadSuccess := os.read_entire_file(
				strings.join(includePathParts[:], ""),
			)
			if !includeCodeReadSuccess {
				return shdStr, .CouldntReadIncludeFile
			}
			append(&includelessCodeSlices, cast(string)includeCodeBytes)
			vertCodeLoopSlice = vertCodeLoopSlice[closingQuote + 2:]
		}
		append(&includelessCodeSlices, vertCodeLoopSlice)
		resolvedShaderCode := strings.join(includelessCodeSlices[:], "")
		if strings.contains(resolvedShaderCode, "#include") {
			return resolvedShaderCode, .DoesntSupportNestedInclude
		}
		return resolvedShaderCode, .None
	} else {
		return shdStr, .None
	}
}

traceLogShaderIncludeError :: proc(err: ResolveShaderIncludesError) {
	switch err {
	case .None:
	case .MissingOpeningQuote:
		rl.TraceLog(.ERROR, "Missing opening '\"' after #include")
	case .MissingClosingQuote:
		rl.TraceLog(.ERROR, "Missing closing '\"' after #include")
	case .FileEndsAfterClosingIncludeQuote:
		rl.TraceLog(.ERROR, "File ends right after #include (add a linebreak or something)")
	case .CouldntReadIncludeFile:
		rl.TraceLog(.ERROR, "Couldn't read include file")
	case .DoesntSupportNestedInclude:
		rl.TraceLog(.ERROR, "Doesn't support nested include")
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
lightShaderPreviousId: u32 = 0
MAX_LIGHTS :: 4
// TODO: Possibly optimizable with constant locations by using a shader include system
applyLightToShader :: proc(shd: rl.Shader) {
	setShaderValue(shd, "ambient", &engine.ambientLightingColor)
	setShaderValue(shd, "viewPos", &global.camera3D.position)

	if shd.id == lightShaderPreviousId {
		return
	}
	lightShaderPreviousId = shd.id

	setShaderValue(shd, "lights[0].enabled", &engine.lights3D[0].enabled)
	type0 := c.int(engine.lights3D[0].type)
	setShaderValue(shd, "lights[0].type", &type0)
	setShaderValue(shd, "lights[0].position", &engine.lights3D[0].position)
	setShaderValue(shd, "lights[0].target", &engine.lights3D[0].target)
	setShaderValue(shd, "lights[0].color", &engine.lights3D[0].color)

	setShaderValue(shd, "lights[1].enabled", &engine.lights3D[1].enabled)
	type1 := c.int(engine.lights3D[1].type)
	setShaderValue(shd, "lights[1].type", &type1)
	setShaderValue(shd, "lights[1].position", &engine.lights3D[1].position)
	setShaderValue(shd, "lights[1].target", &engine.lights3D[1].target)
	setShaderValue(shd, "lights[1].color", &engine.lights3D[1].color)

	setShaderValue(shd, "lights[2].enabled", &engine.lights3D[2].enabled)
	type2 := c.int(engine.lights3D[2].type)
	setShaderValue(shd, "lights[2].type", &type2)
	setShaderValue(shd, "lights[2].position", &engine.lights3D[2].position)
	setShaderValue(shd, "lights[2].target", &engine.lights3D[2].target)
	setShaderValue(shd, "lights[2].color", &engine.lights3D[2].color)

	setShaderValue(shd, "lights[3].enabled", &engine.lights3D[3].enabled)
	type3 := c.int(engine.lights3D[3].type)
	setShaderValue(shd, "lights[3].type", &type3)
	setShaderValue(shd, "lights[3].position", &engine.lights3D[3].position)
	setShaderValue(shd, "lights[3].target", &engine.lights3D[3].target)
	setShaderValue(shd, "lights[3].color", &engine.lights3D[3].color)
}
ACTIVE_LIGHTS :: 1
setLightStatus :: proc(val: i32) {
	for i in 0 ..< ACTIVE_LIGHTS {
		engine.lights3D[i].enabled = val
	}
}

GENERATION_BLOCK_SIZE :: 16
generateCircleMask2D :: proc(radius: i32) -> [dynamic]byte {
	diameter := radius + radius
	maskLength := diameter * diameter
	mask := make([dynamic]byte, maskLength, maskLength)
	center := rl.Vector2{f32(radius) - 0.5, f32(radius) - 0.5}
	for i in 0 ..< maskLength {
		x := i % diameter
		y := i / diameter
		position := rl.Vector2{f32(x), f32(y)}
		distance := linalg.distance(center, position)
		mask[i] = u8(math.step(f32(radius) - 0.25, distance) == 1)
	}
	return mask
}
andMask2D :: proc(
	dest: ^[dynamic]byte,
	destWidth: i32,
	mask: [dynamic]byte,
	maskWidth: i32,
	maskPosition: iVector2,
) {
	assert(linalg.fract(f32(len(dest)) / f32(destWidth)) == 0.0)
	assert(linalg.fract(f32(len(mask)) / f32(maskWidth)) == 0.0)
	destArea := iRectangle{0, 0, destWidth, i32(len(dest)) / destWidth}
	maskArea := iRectangle{maskPosition.x, maskPosition.y, maskWidth, i32(len(mask)) / maskWidth}
	assert(maskArea.x + maskArea.width <= destArea.width)
	assert(maskArea.y + maskArea.height <= destArea.height)
	for x in 0 ..< maskArea.width {
		for y in 0 ..< maskArea.height {
			destX := x + maskArea.x
			destY := y + maskArea.y
			destIndex := destX + destY * destWidth
			dest[destIndex] &= mask[x + y * maskWidth]
		}
	}
}
generateWorld :: proc(area: iRectangle, threshold: f32, seed: i64, frequency: f64) {
	clear(&engine.collisionRectangles)
	blocks := make([dynamic]byte, area.width * area.height, area.width * area.height)
	areaWidth := f64(area.width)
	areaHeight := f64(area.height)
	for x in 0 ..< area.width {
		for y in 0 ..< area.height {
			samplePosition := [2]f64 {
				f64(x) / areaWidth * frequency,
				f64(y) / areaHeight * frequency,
			}
			noiseValue := math.step(threshold, noise.noise_2d(seed, samplePosition))
			blocks[x + y * area.width] = cast(byte)noiseValue
		}
	}
	spawnAreaRadius: i32 = 5
	spawnAreaMask := generateCircleMask2D(spawnAreaRadius)
	andMask2D(
		&blocks,
		area.width,
		spawnAreaMask,
		spawnAreaRadius + spawnAreaRadius,
		{area.width / 2 - spawnAreaRadius, area.height / 2 - spawnAreaRadius},
	)
	blockStartPosition: iVector2
	wasPreviousBlockSolid: bool
	for y in 0 ..< area.height {
		for x in 0 ..< area.width {
			isBlockSolid := blocks[x + y * area.height] == 1
			if !wasPreviousBlockSolid && isBlockSolid {
				blockStartPosition = {x, y}
			} else if wasPreviousBlockSolid && !isBlockSolid {
				collisionRectangle := iRectangle {
					(blockStartPosition.x + area.x) * GENERATION_BLOCK_SIZE,
					(blockStartPosition.y + area.y) * GENERATION_BLOCK_SIZE,
					(x - blockStartPosition.x + 1) * GENERATION_BLOCK_SIZE,
					GENERATION_BLOCK_SIZE,
				}
				append(&engine.collisionRectangles, collisionRectangle)
			}
			if isBlockSolid && x + 1 == area.width {
				collisionRectangle := iRectangle {
					(blockStartPosition.x + area.x) * GENERATION_BLOCK_SIZE,
					(blockStartPosition.y + area.y) * GENERATION_BLOCK_SIZE,
					(x - blockStartPosition.x + 1) * GENERATION_BLOCK_SIZE,
					GENERATION_BLOCK_SIZE,
				}
				append(&engine.collisionRectangles, collisionRectangle)
			}
			wasPreviousBlockSolid = isBlockSolid
		}
	}
}
doSolidCollision :: proc(hitbox: rl.Rectangle) -> Maybe(iRectangle) {
	hitboxI32 := iRectangle{i32(hitbox.x), i32(hitbox.y), i32(hitbox.width), i32(hitbox.height)}
	for rectangle in engine.collisionRectangles {
		if rectangleInRectangle(hitboxI32, rectangle) {
			return rectangle
		}
	}
	return nil
}
drawSolids :: proc() {
	for rectangle in engine.collisionRectangles {
		rectangleF32 := rl.Rectangle {
			f32(rectangle.x),
			f32(rectangle.y),
			f32(rectangle.width),
			f32(rectangle.height),
		}
		rl.DrawRectangleRec(rectangleF32, rl.WHITE)
	}
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
	drawDepth:   i32,
}
GameObjectFuncs :: struct {}
gameObjectEmptyProc :: proc(_: rawptr) {}
createGameObject :: proc(
	$T: typeid,
	data: rawptr,
	drawDepth: i32,
	startProc: proc(_: rawptr) = gameObjectEmptyProc,
	updateProc: proc(_: rawptr) = gameObjectEmptyProc,
	drawProc: proc(_: rawptr) = gameObjectEmptyProc,
	drawEndProc: proc(_: rawptr) = gameObjectEmptyProc,
	destroyProc: proc(_: rawptr) = gameObjectEmptyProc,
) -> ^GameObject {
	append(
		&engine.gameObjects,
		GameObject {
			startProc = startProc,
			updateProc = updateProc,
			drawProc = drawProc,
			drawEndProc = drawEndProc,
			destroyProc = destroyProc,
			data = data,
			drawDepth = drawDepth,
			id = engine.gameObjectIdCounter,
			type = T,
		},
	)

	object := &engine.gameObjects[len(engine.gameObjects) - 1]
	if gameObjectHasDrawEvent(object^) {
		insertGameObjectIntoDrawingOrder(object)
	}

	engine.gameObjectIdCounter += 1
	return object
}
destroyAllGameObjects :: proc() {
	for object in engine.gameObjects {
		object.destroyProc(object.data)
	}
	clear(&engine.gameObjects)
	clear(&engine.gameObjectsDepthOrdered)
}
destroyGameObject :: proc(id: i32) {
	removedGameObject := false
	for i in 0 ..< len(engine.gameObjects) {
		if engine.gameObjects[i].id == id {
			engine.gameObjects[i].destroyProc(engine.gameObjects[i].data)
			unordered_remove(&engine.gameObjects, i)
			removedGameObject = true
			break
		}
	}
	if removedGameObject {
		clear(&engine.gameObjectsDepthOrdered)
		for i in 0 ..< len(engine.gameObjects) {
			if gameObjectHasDrawEvent(engine.gameObjects[i]) {
				insertGameObjectIntoDrawingOrder(&engine.gameObjects[i])
			}
		}
	}
}
gameObjectHasDrawEvent :: proc(object: GameObject) -> bool {
	return object.drawProc != gameObjectEmptyProc || object.drawEndProc != gameObjectEmptyProc
}
insertGameObjectIntoDrawingOrder :: proc(object: ^GameObject) {
	injected := false
	for i in 0 ..< len(engine.gameObjectsDepthOrdered) {
		o := engine.gameObjectsDepthOrdered[i]
		if object.drawDepth > o.drawDepth {
			inject_at(&engine.gameObjectsDepthOrdered, i, object)
			injected = true
			break
		}
	}
	if !injected {
		append(&engine.gameObjectsDepthOrdered, object)
	}
}
setGameObjectStartFunc :: proc()
getGameObjectsOfType :: proc(type: typeid) -> [dynamic]^GameObject {
	context.allocator = context.temp_allocator
	objs := make([dynamic]^GameObject, 0, 10)
	for i in 0 ..< len(engine.gameObjects) {
		if engine.gameObjects[i].type == type {
			append(&objs, &engine.gameObjects[i])
		}
	}
	return objs
}
getGameObjectScreenPos :: proc(obj: ^GameObject) -> rl.Vector2 {
	return obj.pos - global.camera.target + global.camera.offset
}
getFirstGameObjectOfType :: proc($T: typeid) -> ^T {
	for i in 0 ..< len(engine.gameObjects) {
		if engine.gameObjects[i].type == T {
			return cast(^T)engine.gameObjects[i].data
		}
	}
	return nil
}
objectCollision :: proc(object: ^GameObject, offset: rl.Vector2) -> ^GameObject {
	rec := getObjectAbsoluteCollisionRectangle(object, offset)
	for i in 0 ..< len(engine.gameObjects) {
		otherObject := &engine.gameObjects[i]
		if object.id != otherObject.id &&
		   rectangleInRectangle(
			   rec,
			   getObjectAbsoluteCollisionRectangle(otherObject, {0.0, 0.0}),
		   ) {
			return &engine.gameObjects[i]
		}
	}
	return nil
}
objectCollisionType :: proc(object: ^GameObject, type: typeid, offset: rl.Vector2) -> ^GameObject {
	rec := getObjectAbsoluteCollisionRectangle(object, offset)
	for i in 0 ..< len(engine.gameObjects) {
		otherObject := &engine.gameObjects[i]
		if object.id != otherObject.id &&
		   otherObject.type == type &&
		   rectangleInRectangle(
			   rec,
			   getObjectAbsoluteCollisionRectangle(otherObject, {0.0, 0.0}),
		   ) {
			return &engine.gameObjects[i]
		}
	}
	return nil
}
getObjectCenter :: proc(object: GameObject) -> rl.Vector2 {
	return {
		object.colRec.x + object.colRec.width / 2.0,
		object.colRec.y + object.colRec.height / 2.0,
	}
}
getObjectCenterAbsolute :: proc(object: GameObject) -> rl.Vector2 {
	return {
		object.colRec.x + object.colRec.width / 2.0 + object.pos.x,
		object.colRec.y + object.colRec.height / 2.0 + object.pos.y,
	}
}
getObjectAbsoluteCollisionRectangle :: proc(
	object: ^GameObject,
	offset: rl.Vector2,
) -> rl.Rectangle {
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
	for i in 0 ..< len(engine.gameObjects) {
		rl.DrawTexturePro(
			whiteTex,
			whiteTexSrc,
			getObjectAbsoluteCollisionRectangle(&engine.gameObjects[i], {0.0, 0.0}),
			{0.0, 0.0},
			0.0,
			{0, 192, 0, 128},
		)
	}
}

/*
    TODO:
    Starting/ending texture mode while in mode 2d/3d sets some state that makes stuff disappear
    For this to work normally 2d/3d mode needs to be begin/end as well
*/
beginNestedTextureMode :: proc(renderTexture: rl.RenderTexture) {
	if engine.currentRenderTexture == nil {
		engine.currentRenderTexture = renderTexture
		rl.BeginTextureMode(engine.currentRenderTexture.?)
	} else {
		rl.EndTextureMode()
		append(&engine.renderTextureStack, engine.currentRenderTexture.?)
		engine.currentRenderTexture = renderTexture
		rl.BeginTextureMode(engine.currentRenderTexture.?)
	}
}
endNestedTextureMode :: proc() {
	if engine.renderTextureStack == nil {
		panic("No render texture to pop off the stack")
	} else {
		rl.EndTextureMode()
		if len(engine.renderTextureStack) == 0 {
			engine.currentRenderTexture = nil
		} else {
			engine.currentRenderTexture = pop(&engine.renderTextureStack)
			rl.BeginTextureMode(engine.currentRenderTexture.?)
		}
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
getTweenProgressDurationOnly :: proc(tween: Tween) -> f32 {
	return math.max(0.0, (tween.t - tween.delay) / tween.dur)
}
getTweenProgress :: proc(tween: Tween) -> f32 {
	return tween.t / (tween.dur + tween.delay)
}
_createFinishedTween :: proc(range: TweenRange) -> Tween {
	return {range = range, curve = .Linear, dur = 1.0, t = 1.0, delay = 0.0}
}
tweenInvert :: proc(tween: Tween, tweenRangeType: $T) -> Tween {
	invertedTween := createTween(
		T{from = tween.range.(T).to, to = tween.range.(T).from},
		tween.curve,
		tween.dur,
		tween.delay,
	)
	tween.t = (1.0 - getTweenProgress(tween)) * (tween.dur + tween.delay)
	return tween
}
createFinishedTween :: proc {
	createFinishedTweenF32,
	createFinishedTweenI32,
	createFinishedTweenVector2,
	createFinishedTweenVector3,
	createFinishedTweenU8,
}
createFinishedTweenF32 :: proc(val: f32) -> Tween {
	return _createFinishedTween(TweenF32Range{val, val})
}
createFinishedTweenI32 :: proc(val: i32) -> Tween {
	return _createFinishedTween(TweenI32Range{val, val})
}
createFinishedTweenVector2 :: proc(val: rl.Vector2) -> Tween {
	return _createFinishedTween(TweenVector2Range{val, val})
}
createFinishedTweenVector3 :: proc(val: rl.Vector3) -> Tween {
	return _createFinishedTween(TweenVector3Range{val, val})
}
createFinishedTweenU8 :: proc(val: u8) -> Tween {
	return _createFinishedTween(TweenU8Range{val, val})
}

Timer :: struct {
	time:     f32,
	duration: f32,
}
createTimer :: proc(duration: f32) -> Timer {
	assert(duration > 0.0)
	return {time = 0.0, duration = duration}
}
updateTimer :: proc(timer: ^Timer) {
	timer.time = math.min(timer.time + TARGET_TIME_STEP, timer.duration)
}
isTimerFinished :: proc(timer: Timer) -> bool {
	return timer.time == timer.duration
}
getTimerProgress :: proc(timer: Timer) -> f32 {
	return timer.time / timer.duration
}
