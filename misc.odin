package game
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import rl "lib/raylib"

web10CreateTexture :: proc(size: iVector2, spr_def: SpriteDef, num: i32) -> rl.Texture {
	tex_w := size.x * spr_def.frame_count
	assert(tex_w <= MAX_TEXTURE_SIZE)
	spr_list := make([dynamic]Sprite, num, num)
	rect_list := make([dynamic]rl.Rectangle, num, num)
	frame_count := f32(spr_def.frame_count)
	tex_size := getTextureSize(spr_def.tex)
	for i: i32 = 0; i < num; i += 1 {
		spr_list[i] = createSprite(spr_def)
		setSpriteFrame(&spr_list[i], rand.int31_max(spr_def.frame_count))
		rect_list[i] = rl.Rectangle {
			math.floor(f32(rand.int31_max(size.x - spr_def.tex.width))),
			math.floor(f32(rand.int31_max(size.y - spr_def.tex.height))),
			tex_size.x,
			tex_size.y,
		}
	}

	rtex := rl.LoadRenderTexture(tex_w, size.y)
	defer rl.UnloadRenderTexture(rtex)
	beginModeStacked(getZeroCamera2D(), rtex)
	rl.ClearBackground(rl.Color{0, 0, 0, 0})

	for i: i32 = 0; i < spr_def.frame_count; i += 1 {
		xoff := cast(f32)(i * size.x)
		for j: i32 = 0; j < num; j += 1 {
			pos := rl.Vector2{rect_list[j].x + xoff, rect_list[j].y}
			drawSpriteEx(spr_list[j], pos, rl.Vector2{1.0, 1.0})
			advanceSpriteFrame(&spr_list[j])
		}
	}

	endModeStacked()
	img := rl.LoadImageFromTexture(rtex.texture)
	return rl.LoadTextureFromImage(img)
}
web10CreateTexture2D :: proc(
	frameSize: iVector2,
	spriteDefinitions: [dynamic]SpriteDef,
	instanceCount: i32,
) -> rl.Texture {
	spriteDefinitionCount := len(spriteDefinitions)
	assert(spriteDefinitionCount > 0)
	frameCount := spriteDefinitions[0].frame_count
	for definition in spriteDefinitions {
		assert(definition.frame_count == frameCount)
	}
	textureSize := frameSize * {frameCount, cast(i32)spriteDefinitionCount}
	renderTexture := rl.LoadRenderTexture(textureSize.x, textureSize.y)

	spriteList := make([dynamic][dynamic]Sprite, spriteDefinitionCount, spriteDefinitionCount)
	rectangleList := make([dynamic][dynamic]rl.Rectangle, spriteDefinitionCount, spriteDefinitionCount)
	for i in 0 ..< spriteDefinitionCount {
		spriteList[i] = make([dynamic]Sprite, instanceCount, instanceCount)
		rectangleList[i] = make([dynamic]rl.Rectangle, instanceCount, instanceCount)
	}

	for i in 0 ..< len(spriteDefinitions) {
		offsetY := cast(f32)(cast(i32)i * frameSize.y)
		spriteDefinition := spriteDefinitions[i]
		spriteFrameSize := getSpriteDefinitionFrameSize(spriteDefinition)
		spriteFrameSizeF32 := rl.Vector2{cast(f32)spriteFrameSize.x, cast(f32)spriteFrameSize.y}
		for j in 0 ..< instanceCount {
			sprite := createSprite(spriteDefinition)
			setSpriteFrame(&sprite, rand.int31_max(spriteDefinitions[i].frame_count - 1))
			spriteList[i][j] = sprite

			x := rand.float32() * (cast(f32)frameSize.x - spriteFrameSizeF32.x)
			y := rand.float32() * (cast(f32)frameSize.y - spriteFrameSizeF32.y)
			rectangleList[i][j] = {x, y, spriteFrameSizeF32.x, spriteFrameSizeF32.y}
		}
	}

	beginModeStacked(getZeroCamera2D(), renderTexture)
	for i in 0 ..< len(spriteDefinitions) {
		offsetY := cast(f32)(cast(i32)i * frameSize.y)
		for j in 0 ..< frameCount {
			offsetX := cast(f32)(cast(i32)j * frameSize.x)
			for k in 0 ..< instanceCount {
				position := rl.Vector2{rectangleList[i][k].x, rectangleList[i][k].y} + {offsetX, offsetY}
				drawSpriteEx(spriteList[i][k], position, {1.0, 1.0}, rl.WHITE)
				advanceSpriteFrame(&spriteList[i][k])
			}
		}
	}
	endModeStacked()

	image := rl.LoadImageFromTexture(renderTexture.texture)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadRenderTexture(renderTexture)
	rl.UnloadImage(image)
	return texture
}

DEBUG_FONT_SIZE :: 12
getDebugFontSize :: proc() -> i32 {
	return i32(getScreenScale().x * DEBUG_FONT_SIZE)
}
debugDrawFrameTime :: proc(x: i32, y: i32) {
	debugFontSize := getDebugFontSize()
	frameTimeText := rl.TextFormat("Frame time: %fms", rl.GetFrameTime() * 1000.0)
	stringSize := rl.MeasureText(frameTimeText, debugFontSize)
	debugDrawTextOutline(frameTimeText, x - stringSize, y, debugFontSize, rl.WHITE, rl.BLACK)
}
debugDrawPlayerInfo :: proc(player: Player, x: i32, y: i32) {
	debugFontSize := getDebugFontSize()
	positionText := rl.TextFormat("Position: %s", vector2ToStringTemp(player.object.pos))
	dy := y
	debugDrawTextOutline(positionText, x, dy, debugFontSize, rl.WHITE, rl.BLACK)
	dy += debugFontSize
}
debugDrawGlobalCamera3DInfo :: proc(cam: rl.Camera3D, x: i32, y: i32) {
	dy := y
	debugFontSize := getDebugFontSize()
	debugDrawTextOutline(
		rl.TextFormat("pos: %s", vector3ToStringTemp(cam.position)),
		x,
		dy,
		debugFontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += debugFontSize
	debugDrawTextOutline(
		rl.TextFormat("target: %s", vector3ToStringTemp(cam.target)),
		x,
		dy,
		debugFontSize,
		rl.WHITE,
		rl.BLACK,
	)
	dy += debugFontSize
	debugDrawTextOutline(
		rl.TextFormat("look: %s", vector3ToStringTemp(cam.target - cam.position)),
		x,
		dy,
		debugFontSize,
		rl.WHITE,
		rl.BLACK,
	)
}
debugPrintDynamicArenaAllocMessage :: proc(
	allocatorType: string,
	mode: mem.Allocator_Mode,
	loc: runtime.Source_Code_Location,
) {
	fmt.println(
		"(",
		allocatorType,
		")",
		mode,
		"at L:",
		loc.line,
		"C:",
		loc.column,
		"in",
		loc.procedure,
		"(",
		loc.file_path,
		")",
	)
}

StarBackground :: struct {
	genTex:                rl.Texture,
	frameSize:             rl.Vector2,
	spriteCount:           i32,
	frameIndex:            f32,
	frameSpd:              f32,
	frameCount:            i32,
	paralax:               f32,
	scroll:                rl.Vector2,
	scrollSpd:             rl.Vector2,
	scrollSpeedMultiplier: f32,
}
createStarBackground :: proc() -> StarBackground {
	spriteDefinitions := make([dynamic]SpriteDef, 2, 2)
	spriteDefinitions[0] = getSpriteDef(.Star)
	spriteDefinitions[1] = getSpriteDef(.StarSmall)
	return {
		genTex = web10CreateTexture2D({128, 128}, spriteDefinitions, 16),
		frameSize = {128.0, 128.0},
		spriteCount = cast(i32)len(spriteDefinitions),
		frameSpd = 4.0,
		frameCount = getSpriteDef(.Star).frame_count,
		scrollSpd = rl.Vector2{12.0, 12.0},
		scrollSpeedMultiplier = 1.1,
		paralax = 0.9,
	}
}
updateStarBackground :: proc(self: ^StarBackground) {
	self.frameIndex += TARGET_TIME_STEP * self.frameSpd
	self.scroll += self.scrollSpd * TARGET_TIME_STEP
}
drawStarBackground :: proc(self: ^StarBackground, position: rl.Vector2) {
	shd := getShader(.AnimatedTextureRepeatPositionMulti)
	rl.BeginShaderMode(shd)
	setShaderValue(shd, "frameCount", self.frameCount)
	setShaderValue(shd, "spriteCount", self.spriteCount)
	setShaderValue(shd, "frameInd", self.frameIndex)
	setShaderValue(shd, "frameSize", self.frameSize)
	setShaderValue(shd, "scrollPx", self.scroll)
	setShaderValue(shd, "offset", global.camera.offset * self.paralax)
	setShaderValue(shd, "speedMultiplier", self.scrollSpeedMultiplier)
	drawTextureRecDest(self.genTex, {position.x, position.y, RENDER_TEXTURE_WIDTH_2D, RENDER_TEXTURE_HEIGHT_2D})
	rl.EndShaderMode()
	// drawTextureRecDest(self.genTex, {position.x, position.y, cast(f32)self.genTex.width, cast(f32)self.genTex.height})
}
destroyStarBackground :: proc(self: ^StarBackground) {
	rl.UnloadTexture(self.genTex)
}
