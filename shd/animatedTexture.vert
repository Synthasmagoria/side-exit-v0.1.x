attribute vec3 vertexPosition;
attribute vec2 vertexTexCoord;
attribute vec4 vertexColor;

varying vec2 fragPos;
varying vec2 fragTexCoord;
varying vec4 fragCol;

uniform mat4 mvp;
void main() {
    fragPos = vertexPosition.xy;
    fragTexCoord = vertexTexCoord;
    fragCol = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
