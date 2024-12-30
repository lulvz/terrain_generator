#version 330 core

layout(location = 1) in float vertexTileID; // Tile ID (attribute)
in vec3 vertexPosition; // Vertex position attribute

out vec3 fragPosition; // Pass to the fragment shader
out float tileID;

uniform mat4 mvp;

void main() {
    fragPosition = vertexPosition; // Pass the vertex position to the fragment shader
    tileID = vertexTileID; // Pass the tile ID
    gl_Position = mvp*vec4(vertexPosition,1);
}
