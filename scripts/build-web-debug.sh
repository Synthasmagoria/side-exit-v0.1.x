OUT_DIR=build/wasm
mkdir -p $OUT_DIR

odin build . -target:js_wasm32 -build-mode:obj -define:RAYLIB_WASM_LIB=env.o -out:$OUT_DIR/game.wasm.o

ODIN_PATH=$(odin root)

cp $ODIN_PATH/core/sys/wasm/js/odin.js $OUT_DIR

files="$OUT_DIR/game.wasm.o lib/raylib/raylib/build/wasm/release/libraylib.web.a"

# index_template.html contains the javascript code that calls the procedures in
# source/main_web/main_web.odin
flags="-sUSE_GLFW=3 -sWASM_BIGINT -sWARN_ON_UNDEFINED_SYMBOLS=0 -sASSERTIONS --shell-file index_template.html --preload-file tex"
preload=""

# For debugging: Add `-g` to `emcc` (gives better error callstack in chrome)
emcc -o $OUT_DIR/index.html $files $flags

rm $OUT_DIR/game.wasm.o

echo "Web build created in ${OUT_DIR}"
