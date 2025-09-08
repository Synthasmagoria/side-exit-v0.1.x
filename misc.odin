package game
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

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
	rl.BeginTextureMode(rtex)
	rl.ClearBackground(rl.Color{0, 0, 0, 0})

	for i: i32 = 0; i < spr_def.frame_count; i += 1 {
		xoff := cast(f32)(i * size.x)
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
getScreenZoom :: proc() -> f32 {
	screenSize := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	rtexSize := rl.Vector2{WINDOW_WIDTH, WINDOW_HEIGHT}
	if screenSize.x < screenSize.y {
		return screenSize.x / rtexSize.x
	} else {
		return screenSize.y / rtexSize.y
	}
}
drawAppRtex :: proc(rtex: rl.RenderTexture) {
	src := getAppRtexSrcRect(rtex)
	dest := getAppRtexDestRect(rtex)
	origin := rl.Vector2{0.0, 0.0}
	rl.DrawTexturePro(rtex.texture, src, dest, origin, 0.0, rl.WHITE)
}
