#version 100
precision mediump float;

varying vec2 fragPosition;
varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0; // mask texture
uniform vec4 colDiffuse;

uniform sampler2D texture1; // texture texture
uniform vec2 textureResolution;

void main() {
    vec2 uv = fract(fragPosition / textureResolution);
    vec4 maskColor = texture2D(texture0, fragTexCoord);
    vec4 texelColor = texture2D(texture1, uv);
    gl_FragColor = maskColor * texelColor * colDiffuse * fragColor;
}
