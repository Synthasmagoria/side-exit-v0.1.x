#version 100
precision mediump float;

attribute vec3 vertexPosition;
attribute vec2 vertexTexCoord;
attribute vec4 vertexColor;

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform mat4 mvp;

uniform int flipV;

void main() {
    if (flipV == 1) {
        fragTexCoord = vec2(vertexTexCoord.x, 1.0 - vertexTexCoord.y);
    } else {
        fragTexCoord = vertexTexCoord;
    }
    fragPosition = vertexPosition.xy;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
