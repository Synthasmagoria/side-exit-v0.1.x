varying vec2 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

void main() {
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    gl_FragColor = texelColor * colDiffuse * fragCol;
}
