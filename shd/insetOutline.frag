#version 100
precision mediump float;

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 texelSize;
uniform float outlineThickness;

void main() {
    vec2 texel = texelSize * outlineThickness;
    float tl = texture2D(texture0, fragTexCoord + -texel).a;
    float tr = texture2D(texture0, fragTexCoord + vec2(texel.x, -texel.y)).a;
    float bl = texture2D(texture0, fragTexCoord + vec2(-texel.x, texel.y)).a;
    float br = texture2D(texture0, fragTexCoord + texel).a;
    float outline = step(tl + tr + bl + br, 3.5);
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    gl_FragColor = texelColor * colDiffuse * fragColor * outline;
}
