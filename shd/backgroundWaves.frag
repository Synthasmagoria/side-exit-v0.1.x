#version 100
precision highp float;

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform vec2 resolution;
uniform float time;
uniform vec4 color_a;
uniform vec4 color_b;

float smoothplot(float edge, float val, float t, float s) {
    return smoothstep(edge - t - s, edge - t, val) - smoothstep(edge + t, edge + t + s, val);
}

mat2 make_rotation_matrix(float ang) {
    return mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
}

void main() {
    vec2 mult = vec2(resolution.x) / 64.0;
    vec2 pos = floor(fragPosition / mult) * mult;
    vec2 uv = pos / resolution;
    uv += 0.5;
    vec2 uv2 = uv * make_rotation_matrix(0.4) - 0.5;
    vec2 uv3 = uv * make_rotation_matrix(1.2) - 0.5;
    vec2 uv4 = uv * make_rotation_matrix(1.6) - 0.5;
    uv -= 0.5;
    float waves =
        smoothplot(cos(uv2.y * 3.5 + time * 2.12), uv2.x, 0.0, 0.6) * 0.4 +
            smoothplot(sin(uv3.y * 5.5 + time * 1.88), uv3.x, 0.0, 1.2) * 0.4 +
            smoothplot(sin(uv4.y * 10.0 + time * 1.5), uv4.x, 0.0, 2.0) * 0.16;
    vec4 color = mix(color_a, color_b, waves);
    gl_FragColor = color * colDiffuse * fragColor;
}
