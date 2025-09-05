package main

import "core:c"
import "core:fmt"
import math "core:math"
import rand "core:math/rand"
import mem "core:mem"
import string_util "core:strings"
import rl "vendor:raylib"

Alloc :: mem.Allocator

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
createSprite :: proc(spr_def: SpriteDef, frame_ind: f32) -> Sprite {
	// TODO: Make sure frame index isnt out of bounds
	return {spr_def, frame_ind, cast(i32)frame_ind}
}
getSpriteSourceRect :: proc(spr: Sprite) -> rl.Rectangle {
	return {
		cast(f32)(spr.frame_ind * spr.def.frame_w),
		0.0,
		cast(f32)spr.def.frame_w,
		cast(f32)spr.def.tex.height,
	}
}
drawSpriteEx :: proc(spr: Sprite, pos: rl.Vector2, scale: rl.Vector2) {
	src := getSpriteSourceRect(spr)
	frame_w := cast(f32)spr.def.frame_w
	size := rl.Vector2{frame_w, frame_w} * scale
	dest := rl.Rectangle{pos.x, pos.y, size.x, size.y}
	rl.DrawTexturePro(spr.def.tex, src, dest, {0.0, 0.0}, 0.0, rl.WHITE)
}
drawSpriteRect :: proc(spr: Sprite, dest: rl.Rectangle) {
	src := getSpriteSourceRect(spr)
	frame_w := cast(f32)spr.def.tex.width
	rl.DrawTexturePro(spr.def.tex, src, dest, {0.0, 0.0}, 0.0, rl.WHITE)
}
updateSprite :: proc(spr: ^Sprite, t_step := TARGET_TIME_STEP) {
	spr.frame_t = math.mod(spr.frame_t + t_step * spr.def.frame_spd, cast(f32)spr.def.frame_count)
	spr.frame_ind = cast(i32)spr.frame_t
}
advanceSpriteFrame :: proc(spr: ^Sprite) {
	spr.frame_t = math.mod(spr.frame_t + 1.0, cast(f32)spr.def.frame_count)
	spr.frame_ind = cast(i32)spr.frame_t
}

web10CreateTexture :: proc(w: i32, h: i32, spr_def: SpriteDef, num: i32) -> rl.Texture {
	context.allocator = context.temp_allocator
	tex_w := w * spr_def.frame_count
	assert(tex_w <= MAX_TEXTURE_SIZE)
	spr_list := make([dynamic]Sprite, num, num)
	rect_list := make([dynamic]rl.Rectangle, num, num)
	frame_count := cast(f32)spr_def.frame_count
	tex_size := getTextureSize(spr_def.tex)
	for i: i32 = 0; i < num; i += 1 {
		spr_list[i] = createSprite(spr_def, cast(f32)rand.int31_max(spr_def.frame_count))
		rect_list[i] = rl.Rectangle {
			math.floor(cast(f32)(rand.int31_max(w - spr_def.tex.width))),
			math.floor(cast(f32)(rand.int31_max(h - spr_def.tex.height))),
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

getTextureSize :: proc(tex: rl.Texture) -> rl.Vector2 {
	return {cast(f32)tex.width, cast(f32)tex.height}
}

drawAppRtex :: proc(rtex: rl.RenderTexture) {
	src := getAppRtexSrcRect(rtex)
	dest := getAppRtexDestRect(rtex)
	origin := rl.Vector2{0.0, 0.0}
	rl.DrawTexturePro(rtex.texture, src, dest, origin, 0.0, rl.WHITE)
}

loadShader :: proc(path: string) -> rl.Shader {
	context.allocator = context.temp_allocator
	vertPath := [?]string{path, ".vert"}
	fragPath := [?]string{path, ".frag"}
	return rl.LoadShader(
		string_util.clone_to_cstring(string_util.join(vertPath[:], "")),
		string_util.clone_to_cstring(string_util.join(fragPath[:], "")),
	)
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

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE}) // TODO: Remove artifacts from main framebuffer
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "The Great Seeker: Unruly Lands")
	rl.SetTargetFPS(TARGET_FPS)
	defer rl.CloseWindow()

	tempArena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&tempArena)
	defer mem.dynamic_arena_free_all(&tempArena)
	tempAlloc := mem.dynamic_arena_allocator(&tempArena)
	context.temp_allocator = tempAlloc

	starTex := rl.LoadTexture("tex/sStar.png")
	defer rl.UnloadTexture(starTex)
	starSprDef := createSpriteDef(starTex, 4, 5.0)
	starSpr := createSprite(starSprDef, 0.0)
	web10TexSize := rl.Vector2{128.0, 128.0}
	web10Tex := web10CreateTexture(
		cast(i32)web10TexSize.x,
		cast(i32)web10TexSize.y,
		starSprDef,
		16,
	)
	defer rl.UnloadTexture(web10Tex)
	app_rtex := rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	defer rl.UnloadRenderTexture(app_rtex)
	anim_repeat_shd := loadShader("shd/animatedTextureRepeatPosition")
	defer rl.UnloadShader(anim_repeat_shd)

	repeatingStarBg := createRepeatingStarBg(
		anim_repeat_shd,
		web10Tex,
		web10TexSize,
		4.0,
		7,
		rl.Vector2{30.0, 20.0},
	)

	mem.dynamic_arena_reset(&tempArena)

	for !rl.WindowShouldClose() {
		defer mem.dynamic_arena_reset(&tempArena)
		rl.BeginDrawing()
		rl.BeginTextureMode(app_rtex)
		rl.ClearBackground(rl.BLACK)
		drawRepeatingStarBg(&repeatingStarBg)
		rl.EndTextureMode()
		drawAppRtex(app_rtex)
		rl.EndDrawing()
	}
}
