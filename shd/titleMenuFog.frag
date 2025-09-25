#version 100
precision mediump float;

#include "include/snoise.glsl"

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

void main() {
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    float n = snoise(vec3(fragPosition, time));
    gl_FragColor = n * colDiffuse * fragColor;
}
