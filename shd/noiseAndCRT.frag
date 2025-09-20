#version 100
precision mediump float;

float random(vec2 st) {
    return fract(sin(dot(mod(st, 2.386), vec2(58.2894, 28.483))) * 43028.49);
}

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform float noiseFactor;
uniform float crtWidth;
uniform float crtFactor;
uniform float crtSpeed;

void main() {
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    float value = (texelColor.r + texelColor.g + texelColor.b) / 3.0;
    float mask = step(0.1, value);

    float noise = random(fragTexCoord + time);
    float noiseAdd = 1.0 + noise * mask * noiseFactor;
    vec4 noiseColor = vec4(vec3(noiseAdd), 1.0);
    float crt = step(mod(fragPosition.y + time * crtSpeed, crtWidth * 2.0), crtWidth);
    vec4 crtColor = vec4(vec3(1.0 + crt * crtFactor * mask), 1.0);

    gl_FragColor = texelColor * colDiffuse * fragColor * noiseColor * crtColor;
}
