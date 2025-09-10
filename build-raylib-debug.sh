pushd lib/raylib/raylib/src
make clean
make TARGET_PLATFORM=PLATFORM_DESKTOP_GLFW RAYLIB_BUILD_MODE=DEBUG
popd
