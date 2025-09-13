#version 100
precision mediump float;

varying vec3 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;
varying vec3 fragNormal;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

#include "include/lightingImplementation.glsl"

void main() {
    vec3 normal = normalize(fragNormal);
    vec3 viewDir = normalize(viewPos - fragPos);
    LightCalculation light = lightCalculation(normal, viewDir);

    vec4 tint = colDiffuse * fragCol;
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    vec4 finalColor = (texelColor * ((tint + vec4(light.specular, 1.0)) * vec4(light.lightDot, 1.0)));
    finalColor += texelColor * (ambient / 10.0);

    // Gamma correction
    gl_FragColor = pow(finalColor, vec4(1.0 / 2.2));
}
