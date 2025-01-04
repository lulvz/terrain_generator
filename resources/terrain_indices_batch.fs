#version 330 core
in vec3 fragPosition;
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;

void main() {
    // Sample the texture using the calculated texture coordinates
    vec4 texColor = texture(texture0, fragTexCoord);
    finalColor = texColor;
}