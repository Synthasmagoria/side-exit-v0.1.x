package game
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import rl "lib/raylib"

web10CreateTexture :: proc(size: iVector2, spr_def: SpriteDef, num: i32) -> rl.Texture {
	context.allocator = context.temp_allocator
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
