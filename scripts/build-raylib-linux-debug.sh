pushd lib/raylib/raylib/src
OUT_DIR="../build/linux/debug"
rm -rf $OUT_DIR
mkdir -p $OUT_DIR
make clean
make TARGET_PLATFORM=PLATFORM_DESKTOP_GLFW RAYLIB_BUILD_MODE=DEBUG RAYLIB_SRC_PATH=$OUT_DIR
popd
