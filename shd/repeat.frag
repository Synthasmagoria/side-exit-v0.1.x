varying vec2 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 texSize;

void main() {
    vec2 uv = fract(fragPos / texSize);
    vec4 texelColor = texture2D(texture0, uv);
    gl_FragColor = texelColor * colDiffuse * fragCol;
}
