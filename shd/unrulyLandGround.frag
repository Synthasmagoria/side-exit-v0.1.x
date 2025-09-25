#version 100
precision mediump float;

#include "include/snoise.glsl"

float fsnoise3(vec3 st) {
    float n = 0.0;
    const int iter = 3;
    for (int i = 0; i < iter; i++) {
        float f = float(i + 1);
        float fractional = (f + 1.0) / float(iter);
        vec2 pos = st.xy * 2.5 * f + fractional;
        float val = snoise(vec3(pos, st.z + fractional)) * 0.5 + 0.5;
        n += val * (1.0 / pow(2.0, f));
    }
    return n;
}

float random(vec2 st) {
    return fract(sin(dot(mod(st, 2.386), vec2(58.2894, 28.483))) * 43028.49);
}
vec2 random_pos(vec2 id) {
    float r = random(id);
    float r2 = fract(r * 245.829 + 29.1273);
    return vec2(r, r2) * 2.0 - 1.0;
}

float smoothplot(float edge, float val, float t, float s) {
    t /= 2.0;
    s /= 2.0;
    return smoothstep(edge - t - s, edge - t, val) - smoothstep(edge + t, edge + t + s, val);
}

const float TAU = 6.28318;
vec2 angle_to_cartesian(float ang) {
    return vec2(cos(ang * TAU), sin(ang * TAU));
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec2 invlerp(vec2 val, vec2 mn, vec2 mx) {
    return (val - mn) / (mx - mn);
}
vec2 lerp(vec2 val, vec2 mn, vec2 mx) {
    return (mx - mn) * val + mn;
}
vec4 blend_color_normal(vec4 dest, vec4 src) {
    return dest * (1.0 - src.a) + vec4(src.rgb * src.a, src.a);
}
float rgb_val(vec3 col) {
    return (col.r + col.g + col.b) / 3.0;
}

float edge_detect(float edge, float tl, float tr, float bl, float br) {
    float bigger = float(
            (tl < edge && tr >= edge) ||
                (tl < edge && bl >= edge) ||
                (tl < edge && br >= edge) ||
                (tr < edge && br >= edge));
    float smaller = float(
            (tl >= edge && tr < edge) ||
                (tl >= edge && bl < edge) ||
                (tl >= edge && br < edge) ||
                (tr >= edge && br < edge));
    return clamp(bigger + smaller, 0.0, 1.0);
}

varying vec2 fragPosition;
varying vec4 fragColor;
varying vec2 fragTexCoord;

uniform vec4 colDiffuse;
uniform sampler2D texture0;

uniform float time;
uniform vec2 resolution;
uniform vec4 base_color_a;
uniform vec4 base_color_b;
uniform vec4 band_color_a;
uniform vec4 band_color_b;
uniform float scale;
uniform float band_add;
uniform float turbulence_amplitude;
uniform float turbulence_speed;
uniform float turbulence_frequency;
uniform float turbulence_exp;

#define TURB_NUM 8.0

vec2 sample_turbulence(vec2 st) {
    float freq = turbulence_frequency;
    mat2 rot = mat2(0.6, -0.8, 0.8, 0.6);
    for (float i = 0.0; i < TURB_NUM; i++) {
        float phase = freq * (st * rot).y + turbulence_speed * time + i;
        st += turbulence_amplitude * rot[0] * sin(phase) / freq;
        rot *= mat2(0.6, -0.8, 0.8, 0.6);
        freq *= turbulence_exp;
    }
    return st;
}

float make_star(vec2 st, vec2 id) {
    float star = 0.0;
    float len = dot(st, st);
    float z = random(id);
    float glow = fract(z * 37.923 + 148.284);
    float glow_anim = glow * sin(time * 2.0 + z * TAU) * 0.5 + 0.5;
    star += (0.5 + (z * 0.002)) / len;
    return star * (0.25 + z * 0.75) * glow_anim;
}

#define NEIGHBOR_CHECK_RADIUS 1
vec4 make_starfield(vec2 st) {
    st /= resolution.y / resolution.x;
    vec2 iuv = floor(st);
    vec3 star = vec3(0.0);
    for (int x = -NEIGHBOR_CHECK_RADIUS; x < NEIGHBOR_CHECK_RADIUS; x++) {
        for (int y = -NEIGHBOR_CHECK_RADIUS; y < NEIGHBOR_CHECK_RADIUS; y++) {
            vec2 off = vec2(x, y);
            vec2 fuv = fract(st);
            vec2 randpos = random_pos(iuv - off) * 0.5;
            float r = fract(randpos.x * 52.85 + 19.24);
            vec3 col = hsv2rgb(vec3(r, 0.4, 1.0));
            star += col * make_star(fuv + off - randpos, iuv - off);
        }
    }
    return vec4(star, rgb_val(star));
}

#define THRESHOLD_A 0.4
#define THRESHOLD_B 0.7

void main() {
    vec2 pos = fragPosition / resolution * scale;
    vec2 texel = 1.0 / resolution * scale;
    vec2 pos_tl = sample_turbulence(pos);
    vec2 pos_tr = sample_turbulence(pos + vec2(texel.x, 0.0));
    vec2 pos_bl = sample_turbulence(pos + vec2(0.0, texel.y));
    vec2 pos_br = sample_turbulence(pos + texel);

    float t = time * 0.1;
    float n = snoise(vec3(sample_turbulence(pos), t * 0.5));
    float n_tl = snoise(vec3(pos_tl * scale, t)) * 0.5 + 0.5;
    float n_tr = snoise(vec3(pos_tr * scale, t)) * 0.5 + 0.5;
    float n_bl = snoise(vec3(pos_bl * scale, t)) * 0.5 + 0.5;
    float n_br = snoise(vec3(pos_br * scale, t)) * 0.5 + 0.5;

    float edge_mask_a = snoise(vec3(pos * scale, t * 0.1234));
    float edges_a = clamp(edge_detect(THRESHOLD_A, n_tl, n_tr, n_bl, n_br) * edge_mask_a, 0.0, 1.0);
    float edge_mask_b = snoise(vec3((pos + 1.478) * 2.459, t * 0.1));
    float edges_b = clamp(edge_detect(0.2, n_tl, n_tr, n_bl, n_br) * edge_mask_b, 0.0, 1.0);
    vec4 bands =
        vec4(band_color_a.rgb, band_color_a.a) * edges_a +
            vec4(band_color_b.rgb, band_color_b.a) * edges_b;

    vec4 turbulent_starfield = clamp(make_starfield(sample_turbulence(pos) * 2.0), 0.0, 1.0);
    vec4 col = mix(base_color_a, base_color_b, n + random(pos) * 0.2 - turbulent_starfield);
    col = mix(blend_color_normal(col, bands), col + vec4(bands.rgb * bands.a, 1.0), band_add);
    gl_FragColor = col * fragColor * texture2D(texture0, fragTexCoord);
}
