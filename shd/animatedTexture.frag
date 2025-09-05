varying vec2 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform int frameCount;
uniform float frameInd;

void main() {
    float fc = float(frameCount);
    float animationOffset = floor(frameInd) / fc;
    float frameWidth = 1.0 / fc;
    vec2 uv = vec2(fragTexCoord.x / fc + animationOffset, fragTexCoord.y);
    vec4 texelColor = texture2D(texture0, uv);
    gl_FragColor = texelColor * colDiffuse * fragCol;
}
