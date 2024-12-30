#version 330 core

layout(location = 0) in float vertexHeight; // Input height for each vertex
in vec2 vertexTexCoord;

out vec3 fragPosition; // Pass to the fragment shader
out vec2 fragTexCoord;

uniform mat4 mvp;
float gridSize = 16.0; // CHUNK_SIZE_VERTICES
float gridSpacing = 1.0; // Distance between vertices

void main() {
    // Calculate quad index and vertex within the quad
    int quadIndex = gl_VertexID / 6; // Each quad has 6 vertices (2 triangles)
    int vertexInQuad = gl_VertexID % 6; // Vertex index within the quad

    // Extract grid x and z positions based on the quad layout
    float x, z;

    if (vertexInQuad == 0) {
        x = mod(float(quadIndex), (gridSize)) * gridSpacing; // First vertex of quad
        z = floor(float(quadIndex) / (gridSize)) * gridSpacing;
    } else if (vertexInQuad == 1) {
        x = mod(float(quadIndex), (gridSize)) * gridSpacing; // Second vertex
        z = (floor(float(quadIndex) / (gridSize)) + 1.0) * gridSpacing;
    } else if (vertexInQuad == 2) {
        x = (mod(float(quadIndex), (gridSize)) + 1.0) * gridSpacing; // Third vertex
        z = floor(float(quadIndex) / (gridSize)) * gridSpacing;
    } else if (vertexInQuad == 3) {
        x = (mod(float(quadIndex), (gridSize)) + 1.0) * gridSpacing; // Fourth vertex
        z = floor(float(quadIndex) / (gridSize)) * gridSpacing;
    } else if (vertexInQuad == 4) {
        x = mod(float(quadIndex), (gridSize)) * gridSpacing; // Fifth vertex
        z = (floor(float(quadIndex) / (gridSize)) + 1.0) * gridSpacing;
    } else { // vertexInQuad == 5
        x = (mod(float(quadIndex), (gridSize)) + 1.0) * gridSpacing; // Sixth vertex
        z = (floor(float(quadIndex) / (gridSize)) + 1.0) * gridSpacing;
    }

    // Combine into vertex position
    vec3 vertexPosition = vec3(x, vertexHeight, z);

    fragPosition = vertexPosition; // Pass the vertex position to the fragment shader
    fragTexCoord = vertexTexCoord;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
