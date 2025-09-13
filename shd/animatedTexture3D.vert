#version 100
precision mediump float;

attribute vec3 vertexPosition;
attribute vec2 vertexTexCoord;
attribute vec4 vertexColor;
attribute vec3 vertexNormal;

varying vec3 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;
varying vec3 fragNormal;

uniform int frameCount;
uniform float frameIndex;
uniform mat4 mvp;
uniform mat4 matModel;

#include "include/matrixUtil.glsl"

void main() {
    fragPos = vec3(matModel * vec4(vertexPosition, 1.0));
    fragCol = vertexColor;

    float frameWidth = 1.0 / float(frameCount);
    float frameOffset = frameWidth * mod(frameIndex, float(frameCount));
    fragTexCoord = vertexTexCoord * vec2(frameWidth, 1.0) + vec2(frameOffset, 0.0);

    mat3 matNormal = transpose(inverse(mat3(matModel)));
    fragNormal = normalize(matNormal * vertexNormal);
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
