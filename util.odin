package game
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:reflect"
import "core:strings"
import rl "lib/raylib"
import rlgl "lib/raylib/rlgl"

@(require_results)
readEntireFile :: proc(
	name: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	data: []byte,
	success: bool,
) {
	return _readEntireFile(name, allocator, loc)
}

writeEntireFile :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	return _writeEntireFile(name, data, truncate)
}

when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
	// These will be linked in by emscripten.
	@(default_calling_convention = "c")
	foreign _ {
		fopen :: proc(filename, mode: cstring) -> ^FILE ---
		fseek :: proc(stream: ^FILE, offset: c.long, whence: Whence) -> c.int ---
		ftell :: proc(stream: ^FILE) -> c.long ---
		fclose :: proc(stream: ^FILE) -> c.int ---
		fread :: proc(ptr: rawptr, size: c.size_t, nmemb: c.size_t, stream: ^FILE) -> c.size_t ---
		fwrite :: proc(ptr: rawptr, size: c.size_t, nmemb: c.size_t, stream: ^FILE) -> c.size_t ---
	}

	@(private = "file")
	FILE :: struct {}

	Whence :: enum c.int {
		SET,
		CUR,
		END,
	}

	// Similar to raylib's LoadFileData
	_readEntireFile :: proc(
		name: string,
		allocator := context.allocator,
		loc := #caller_location,
	) -> (
		data: []byte,
		success: bool,
	) {
		if name == "" {
			log.error("No file name provided")
			return
		}

		file := fopen(strings.clone_to_cstring(name, context.temp_allocator), "rb")

		if file == nil {
			log.errorf("Failed to open file %v", name)
			return
		}

		defer fclose(file)

		fseek(file, 0, .END)
		size := ftell(file)
		fseek(file, 0, .SET)

		if size <= 0 {
			log.errorf("Failed to read file %v", name)
			return
		}

		data_err: runtime.Allocator_Error
		data, data_err = make([]byte, size, allocator, loc)

		if data_err != nil {
			log.errorf("Error allocating memory: %v", data_err)
			return
		}

		read_size := fread(raw_data(data), 1, c.size_t(size), file)

		if read_size != c.size_t(size) {
			log.warnf("File %v partially loaded (%i bytes out of %i)", name, read_size, size)
		}

		log.debugf("Successfully loaded %v", name)
		return data, true
	}

	// Similar to raylib's SaveFileData.
	//
	// Note: This can save during the current session, but I don't think you can
	// save any data between sessions. So when you close the tab your saved files
	// are gone. Perhaps you could communicate back to emscripten and save a cookie.
	// Or communicate with a server and tell it to save data.
	_writeEntireFile :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
		if name == "" {
			log.error("No file name provided")
			return
		}

		file := fopen(
			strings.clone_to_cstring(name, context.temp_allocator),
			truncate ? "wb" : "ab",
		)
		defer fclose(file)

		if file == nil {
			log.errorf("Failed to open '%v' for writing", name)
			return
		}

		bytes_written := fwrite(raw_data(data), 1, len(data), file)

		if bytes_written == 0 {
			log.errorf("Failed to write file %v", name)
			return
		} else if bytes_written != len(data) {
			log.errorf(
				"File partially written, wrote %v out of %v bytes",
				bytes_written,
				len(data),
			)
			return
		}

		log.debugf("File written successfully: %v", name)
		return true
	}
} else {
	_readEntireFile :: proc(
		name: string,
		allocator := context.allocator,
		loc := #caller_location,
	) -> (
		data: []byte,
		success: bool,
	) {
		return os.read_entire_file(name, allocator, loc)
	}

	_writeEntireFile :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
		return os.write_entire_file(name, data, truncate)
	}
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

wrapi :: proc(val, mn, mx: $T) -> T {
	newVal := val - mn
	newVal = T(f32(newVal) - math.floor(f32(val) / f32(mx - mn)) * f32(mx - mn))
	return newVal + mn
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
	return {offset.x, offset.y, textureSize.x, textureSize.y}
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

pointInCircle :: proc(point: rl.Vector2, circlePosition: rl.Vector2, circleRadius: f32) -> bool {
	return linalg.distance(point, circlePosition) < circleRadius
}
rectangleInRectangle :: proc {
	rectangleInRectangleF32,
	rectangleInRectangleI32,
}
rectangleInRectangleF32 :: proc(a: rl.Rectangle, b: rl.Rectangle) -> bool {
	return(
		a.x + a.width >= b.x &&
		a.x < b.x + b.width &&
		a.y + a.height >= b.y &&
		a.y < b.y + b.height \
	)
}
rectangleInRectangleI32 :: proc(a: iRectangle, b: iRectangle) -> bool {
	return(
		a.x + a.width >= b.x &&
		a.x < b.x + b.width &&
		a.y + a.height >= b.y &&
		a.y < b.y + b.height \
	)
}
pointInRectangle :: proc {
	pointInRectangleF32,
	pointInRectangleI32,
}
pointInRectangleF32 :: proc(point: rl.Vector2, rectangle: rl.Rectangle) -> bool {
	return(
		point.x >= rectangle.x &&
		point.x < rectangle.x + rectangle.width &&
		point.y >= rectangle.y &&
		point.y < rectangle.y + rectangle.height \
	)
}
pointInRectangleI32 :: proc(point: iVector2, rectangle: iRectangle) -> bool {
	return(
		point.x >= rectangle.x &&
		point.x < rectangle.x + rectangle.width &&
		point.y >= rectangle.y &&
		point.y < rectangle.y + rectangle.height \
	)
}
shiftRectangle :: proc(rec: rl.Rectangle, off: rl.Vector2) -> rl.Rectangle {
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

getRlRectangleCenter :: proc(rectangle: rl.Rectangle) -> rl.Vector2 {
	return {rectangle.x + rectangle.width / 2.0, rectangle.y + rectangle.height / 2.0}
}
getIRectangleCenter :: proc(rectangle: iRectangle) -> iVector2 {
	return {rectangle.x + rectangle.width >> 1, rectangle.y + rectangle.height >> 1}
}

getScreenScale :: proc() -> rl.Vector2 {
	screenSize := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	return screenSize / rl.Vector2{RENDER_TEXTURE_WIDTH_2D, RENDER_TEXTURE_HEIGHT_2D}
}

vector3ToStringTemp :: proc(v: rl.Vector3) -> cstring {
	return rl.TextFormat("{{%f, %f, %f}}", v.x, v.y, v.z)
}
vector2ToStringTemp :: proc(v: rl.Vector2) -> cstring {
	return rl.TextFormat("{{%f, %f}}", v.x, v.y)
}

HorizontalTextAlign :: enum {
	Left,
	Center,
	Right,
}
VerticalTextAlign :: enum {
	Top,
	Middle,
	Bottom,
}
drawTextAligned :: proc(
	text: cstring,
	position: rl.Vector2,
	font: rl.Font,
	fontSize: f32,
	color: rl.Color,
	horizontalAlign: HorizontalTextAlign,
	verticalAlign: VerticalTextAlign,
) {
	textSize := rl.MeasureTextEx(font, text, fontSize, 1.0)
	textPosition: rl.Vector2 = {0.0, 0.0}
	switch horizontalAlign {
	case .Left:
		textPosition.x = position.x
	case .Center:
		textPosition.x = position.x - textSize.x / 2.0
	case .Right:
		textPosition.x = position.x - textSize.x
	}
	switch verticalAlign {
	case .Top:
		textPosition.y = position.y
	case .Middle:
		textPosition.y = position.y - textSize.y / 2.0
	case .Bottom:
		textPosition.y = position.y - textSize.y
	}
	rl.DrawTextEx(font, text, textPosition, fontSize, 1.0, color)
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
	src := getTextureRec(rtex.texture)
	flipShader := getShader(.FlipY)
	rl.BeginShaderMode(flipShader)
	rl.DrawTexturePro(rtex.texture, src, dest, {0.0, 0.0}, 0.0, rl.WHITE)
	rl.EndShaderMode()
}

drawTextureRecDest :: proc(tex: rl.Texture, dest: rl.Rectangle) {
	rl.DrawTexturePro(tex, getTextureRec(tex), dest, rl.Vector2{0.0, 0.0}, 0.0, rl.WHITE)
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

printArray2D :: proc(array: [dynamic]$T, arrayWidth: i32) {
	assert(linalg.fract(f32(len(array)) / f32(arrayWidth)) == 0.0)
	rowCount := i32(len(array)) / arrayWidth
	for i in 0 ..< rowCount {
		fmt.println(array[i * arrayWidth:(i + 1) * arrayWidth])
	}
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

smoothplot :: proc(x: f32, threshold: f32, thickness: f32, smoothing: f32) -> f32 {
	return(
		math.smoothstep(threshold - thickness - smoothing, threshold - thickness, x) -
		math.smoothstep(threshold + thickness, threshold + thickness + smoothing, x) \
	)
}
