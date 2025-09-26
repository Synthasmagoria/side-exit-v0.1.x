#version 100
precision mediump float;

varying vec2 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform int frameCount;
uniform float frameInd;
uniform vec2 frameSize;
uniform vec2 offset;

void main() {
    float fc = float(frameCount);
    vec2 pos = fragPos + offset;
    vec2 st = fract(pos / frameSize);
    vec2 ist = floor(pos / frameSize);

    float animationOffset = frameInd / fc;
    vec2 uv = vec2(st.x / fc + animationOffset, st.y);
    vec4 texelColor = texture2D(texture0, uv);
    gl_FragColor = texelColor * colDiffuse * fragCol;
}
