#version 330 core

in vec3 vertexPosition; // Vertex position attribute

out vec3 fragPosition; // Pass to the fragment shader

uniform mat4 mvp;

void main() {
    fragPosition = vertexPosition; // Pass the vertex position to the fragment shader
    gl_Position = mvp*vec4(vertexPosition,1);
}
