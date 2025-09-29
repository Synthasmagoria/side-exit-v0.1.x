#version 100
precision mediump float;

attribute vec3 vertexPosition;
attribute vec2 vertexTexCoord;
attribute vec4 vertexColor;

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform int flipX;
uniform int flipY;

uniform mat4 mvp;
void main() {
    fragPosition = vertexPosition.xy;
    if (flipX == 0) {
        fragTexCoord.x = vertexTexCoord.x;
    } else {
        fragTexCoord.x = 1.0 - vertexTexCoord.x;
    }
    if (flipY == 0) {
        fragTexCoord.y = vertexTexCoord.y;
    } else {
        fragTexCoord.y = 1.0 - vertexTexCoord.y;
    }
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
