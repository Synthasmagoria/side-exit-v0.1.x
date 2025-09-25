#version 100
precision highp float;

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform vec4 colDiffuse;

uniform vec2 resolution;
uniform float time;
uniform vec4 color_a;
uniform vec4 color_b;
uniform vec2 offset;

float smoothplot(float edge, float val, float t, float s) {
    return smoothstep(edge - t - s, edge - t, val) - smoothstep(edge + t, edge + t + s, val);
}
float random(vec2 st) {
    return fract(sin(dot(mod(st, 2.386), vec2(58.2894, 28.483))) * 43028.49);
}
mat2 make_rotation_matrix(float ang) {
    return mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
}
const float size_decrease = 0.1;

void main() {
    vec2 st = floor((fragPosition + offset) / 6.0) * 6.0 / resolution;
    st = st * 2.0 - 1.0;
    st *= make_rotation_matrix(1.0);
    float wave = smoothplot(sin(st.x * 50.0 + time) * 0.1, 0.0, 0.0, 0.1);
    gl_FragColor = mix(color_a, color_b, wave) * colDiffuse;
}
