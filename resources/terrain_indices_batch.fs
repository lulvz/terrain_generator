#version 330 core
in vec3 fragPosition;
in vec2 fragTexCoord;
out vec4 finalColor;
uniform sampler2D texture0;

void main() {
    // Sample the texture using the calculated texture coordinates
    vec4 texColor = texture(texture0, fragTexCoord);
    // vec2 e;
    // e.x = 0;
    // e.y = 0;
    // vec4 texColor = texture(texture0, e);
    finalColor = texColor;
}
