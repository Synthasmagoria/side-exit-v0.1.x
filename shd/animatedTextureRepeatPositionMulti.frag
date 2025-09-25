#version 100
precision mediump float;

varying vec2 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform int spriteCount;
uniform int frameCount;
uniform float frameInd;
uniform vec2 frameSize;
uniform vec2 scrollPx;
uniform vec2 offset;
uniform float speedMultiplier;

float random(vec2 st) {
    return fract(sin(dot(mod(st, 2.386), vec2(58.2894, 28.483))) * 43028.49);
}

vec2 rot90(vec2 st) {
    return vec2(-st.y, st.x);
}

vec2 rot270(vec2 st) {
    return vec2(st.y, -st.x);
}

vec4 blend_color_normal(vec4 dest, vec4 src) {
    return dest * (1.0 - src.a) + vec4(src.rgb * src.a, src.a);
}

void main() {
    float fc = float(frameCount);
    float sc = float(spriteCount);
    float speed = 1.0;
    gl_FragColor = vec4(0.0);

    for (int i = 0; i < spriteCount; i++) {
        vec2 pos = fragPos + scrollPx * speed + offset;
        vec2 st = fract(pos / frameSize);
        vec2 ist = floor(pos / frameSize);

        vec2 r = vec2(random(ist), random(ist + 0.638548));
        vec2 flip = step(vec2(0.5), r);
        st = mix(st, 1.0 - st, flip);

        st -= 0.5;
        float rotate90 = step(0.5, fract((r.x + 9.248) * 935.9239));
        st = mix(st, rot90(st), rotate90);
        float rotate270 = step(0.5, fract((r.y + 2.395) * 345.2959));
        st = mix(st, rot270(st), rotate270);
        st += 0.5;

        float animationFrameRandom = fract((r.x + 0.39338) * 1.3959);
        float animationOffset = floor(frameInd + animationFrameRandom * fc) / fc;
        float spriteOffset = float(i) / sc;
        vec2 uv = vec2(st.x / fc + animationOffset, st.y / sc + spriteOffset);
        vec4 texelColor = texture2D(texture0, uv);
        gl_FragColor = blend_color_normal(gl_FragColor, texelColor * colDiffuse * fragCol);
        speed *= speedMultiplier;
    }
}
