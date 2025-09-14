package game
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:reflect"
import rl "lib/raylib"
import rlgl "lib/raylib/rlgl"

unloadMaterialMapOnly :: proc(material: rl.Material) {
	raylibFree(material.maps)
}
unloadMaterialNoMap :: proc(material: rl.Material) {
	if material.shader.id != rlgl.GetShaderIdDefault() {
		rl.UnloadShader(material.shader)
	}
	if material.maps != nil {
		for i in 0 ..< len(reflect.enum_field_names(rl.MaterialMapIndex)) {
			if material.maps[i].texture.id != rlgl.GetTextureIdDefault() {
				rl.UnloadTexture(material.maps[i].texture)
			}
		}
	}
}

charLower :: proc(c: u8) -> u8 {
	if c >= 'A' && c <= 'Z' {
		return c + ('a' - 'A')
	}
	return c
}
getTextureSize :: proc(tex: rl.Texture) -> rl.Vector2 {
	return {f32(tex.width), f32(tex.height)}
}
getTextureDestRecCentered :: proc(tex: rl.Texture, areaSize: rl.Vector2) -> rl.Rectangle {
	texSize := getTextureSize(tex)
	return {
		areaSize.x / 2.0 - texSize.x / 2.0,
		areaSize.y / 2.0 - texSize.y / 2.0,
		texSize.x,
		texSize.y,
	}
}
getTextureDestinationRectangle :: proc(texture: rl.Texture, offset: rl.Vector2) -> rl.Rectangle {
    textureSize := getTextureSize(texture)
    return {
        offset.x,
        offset.y,
        textureSize.x,
        textureSize.y,
    }
}
getTextureDestRecCenteredFit :: proc(
	tex: rl.Texture,
	areaSize: rl.Vector2,
	inset: f32,
) -> rl.Rectangle {
	texSize := getTextureSize(tex)
	maxTexLength := max(texSize.x, texSize.y)
	maxAreaLength := max(areaSize.x, areaSize.y)
	if texSize.x > areaSize.x || texSize.y > areaSize.y {
		if texSize.x > texSize.y {
			texSize *= areaSize.x / texSize.x
		} else {
			texSize *= areaSize.y / texSize.y
		}
	}
	rect := rl.Rectangle {
		areaSize.x / 2.0 - texSize.x / 2.0 + inset / 2.0,
		areaSize.y / 2.0 - texSize.y / 2.0 + inset / 2.0,
		texSize.x - inset,
		texSize.y - inset,
	}
	return rect
}
getTextureRec :: proc(tex: rl.Texture) -> rl.Rectangle {
	return {0.0, 0.0, f32(tex.width), f32(tex.height)}
}
getTextureRecYflip :: proc(tex: rl.Texture) -> rl.Rectangle {
	return {0.0, f32(tex.height), f32(tex.width), -f32(tex.height)}
}

pointInRec :: proc(point: rl.Vector2, rectangle: rl.Rectangle) -> bool {
	return(
		point.x >= rectangle.x &&
		point.x < rectangle.x + rectangle.width &&
		point.y >= rectangle.y &&
		point.y < rectangle.y + rectangle.height \
	)
}
pointInCircle :: proc(point: rl.Vector2, circlePosition: rl.Vector2, circleRadius: f32) -> bool {
	return linalg.distance(point, circlePosition) < circleRadius
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
recShift :: proc(rec: rl.Rectangle, off: rl.Vector2) -> rl.Rectangle {
	return {rec.x + off.x, rec.y + off.y, rec.width, rec.height}
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

drawRenderTextureScaledToScreenBuffer :: proc(rtex: rl.RenderTexture) {
	rtex_size := getTextureSize(rtex.texture)
	screen_size := rl.Vector2{cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()}
	dest: rl.Rectangle
	if screen_size.x < screen_size.y {
		h := screen_size.x / rtex_size.x * rtex_size.y
		dest = {0.0, screen_size.y / 2.0 - h / 2.0, screen_size.x, h}
	} else {
		w := screen_size.y / rtex_size.y * rtex_size.x
		dest = {screen_size.x / 2.0 - w / 2.0, 0.0, w, screen_size.y}
	}
	src := getTextureRecYflip(rtex.texture)
	rl.DrawTexturePro(rtex.texture, src, dest, {0.0, 0.0}, 0.0, rl.WHITE)
}

drawTextureRecDest :: proc(tex: rl.Texture, dest: rl.Rectangle) {
	rl.DrawTexturePro(tex, getTextureRec(tex), dest, rl.Vector2{0.0, 0.0}, 0.0, rl.WHITE)
}
vector3ToStringTemp :: proc(v: rl.Vector3) -> cstring {
	return rl.TextFormat("{{%f, %f, %f}}", v.x, v.y, v.z)
}
debugDrawTextOutline :: proc(
	text: cstring,
	x: i32,
	y: i32,
	fontSize: i32,
	color: rl.Color,
	outlineColor: rl.Color,
) {
	rl.DrawText(text, x - 1, y - 1, fontSize, outlineColor)
	rl.DrawText(text, x + 1, y - 1, fontSize, outlineColor)
	rl.DrawText(text, x + 1, y + 1, fontSize, outlineColor)
	rl.DrawText(text, x - 1, y + 1, fontSize, outlineColor)
	rl.DrawText(text, x, y, fontSize, color)
}

setShaderValue :: proc {
	setShaderValueFloat,
	setShaderValueInt,
	setShaderValueCInt,
	setShaderValueVec2,
	setShaderValueVec3,
	setShaderValueVec4,
}
setShaderValueFloat :: proc(shd: rl.Shader, uniformName: cstring, val: ^f32) {
	rl.SetShaderValue(shd, rl.GetShaderLocation(shd, uniformName), val, .FLOAT)
}
setShaderValueInt :: proc(shd: rl.Shader, uniformName: cstring, val: ^int) {
	rl.SetShaderValue(shd, rl.GetShaderLocation(shd, uniformName), val, .INT)
}
setShaderValueCInt :: proc(shd: rl.Shader, uniformName: cstring, val: ^c.int) {
	rl.SetShaderValue(shd, rl.GetShaderLocation(shd, uniformName), val, .INT)
}
setShaderValueVec2 :: proc(shd: rl.Shader, uniformName: cstring, val: ^rl.Vector2) {
	rl.SetShaderValue(shd, rl.GetShaderLocation(shd, uniformName), val, .VEC2)
}
setShaderValueVec3 :: proc(shd: rl.Shader, uniformName: cstring, val: ^rl.Vector3) {
	rl.SetShaderValue(shd, rl.GetShaderLocation(shd, uniformName), val, .VEC3)
}
setShaderValueVec4 :: proc(shd: rl.Shader, uniformName: cstring, val: ^rl.Vector4) {
	rl.SetShaderValue(shd, rl.GetShaderLocation(shd, uniformName), val, .VEC4)
}
loadPassthroughMaterial3D :: proc(albedoTexture: Maybe(rl.Texture) = nil) -> rl.Material {
	material := rl.LoadMaterialDefault()
	material.shader = getShader(.Passthrough3D)
	if albedoTexture != nil {
		rl.SetMaterialTexture(&material, .ALBEDO, albedoTexture.?)
	}
	return material
}

enumNext :: proc(value: $T) -> T {
	return T((i64(value) + 1) % i64(len(reflect.enum_field_names(T))))
}
enumPrev :: proc(value: $T) -> T {
	nextState := i64(value) - 1
	if nextState < 0 {
		return T(len(reflect.enum_field_names(T)) - 1)
	}
	return T(nextState)
}
isEnumFirst :: proc(value: $T) -> bool {
	return reflect.enum_field_values(T)[0] == reflect.Type_Info_Enum_Value(value)
}
isEnumLast :: proc(value: $T) -> bool {
	values := reflect.enum_field_values(T)
	return values[len(values) - 1] == reflect.Type_Info_Enum_Value(value)
}
