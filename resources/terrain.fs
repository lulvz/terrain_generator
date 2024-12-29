#version 330 core

in vec3 fragPosition; // Position of the vertex passed from the vertex shader
out vec4 finalColor;  // Output color of the fragment

uniform sampler2D texture0; // Texture sampler

void main() {
    vec4 texColor = texture(texture0, fragPosition.xz / 16.0);

    // Set the final fragment color
    finalColor = texColor;
}
