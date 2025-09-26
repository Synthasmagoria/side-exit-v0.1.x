#version 100
precision highp float;

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float time;

#include "include/snoise.glsl"

#define FBM_OCTAVES 5
float snoise_fbm(vec3 st) {
    float n = 0.0;
    float octs = float(FBM_OCTAVES);
    for (int i = 0; i < FBM_OCTAVES; i++) {
        float f = float(i);
        float snx = snoise(vec3(st.xy, st.z + f * 0.273));
        float sny = snoise(vec3(st.xy + vec2(4.2894, 2.38549), st.z + f * 0.273 + 10.9858));
        float fbm = snoise(vec3(st.x + snx, st.y + sny, st.z + f * 0.9568)) * 0.5 + 0.5;
        n += fbm * (1.0 / float(FBM_OCTAVES));
        st.xy *= 1.7;
    }
    return n;
}

void main() {
    float gradient = smoothstep(-240.0, 180.0, fragPosition.y);
    vec2 st = fragPosition * 0.001;
    st.y += time * 0.01;
    vec4 fog = vec4(vec3(1.0), snoise_fbm(vec3(st, time * 0.2)) * gradient);
    gl_FragColor = fog * colDiffuse * fragColor;
}
