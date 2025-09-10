package game
import "core:math"
import "core:math/rand"
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
