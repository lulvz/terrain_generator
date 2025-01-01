#version 330 core

layout(location = 0) in float vertexHeight; // Input height for each vertex
in vec2 vertexTexCoord;

out vec3 fragPosition; // Pass to the fragment shader
out vec2 fragTexCoord;

out vec2 vBary;

uniform mat4 mvp;
float gridSize = 17.0; // CHUNK_SIZE_VERTICES
float gridSpacing = 1.0; // Distance between vertices

void main() {
    // Calculate the x and z based on the strip structure
    int row = gl_VertexID / int(gridSize * 2); // Each row has 2 * gridSize vertices
    int col = gl_VertexID % int(gridSize * 2); // Column index within the row

    float x = float(col / 2) * gridSpacing; // x depends on the column
    float z = float(row + (col % 2)) * gridSpacing; // z alternates between rows
    // Combine into vertex position
    vec3 vertexPosition = vec3(x, vertexHeight, z);

    // Calculate barycentric coordinates
    int vertexInTriangle = gl_VertexID % 3; // Vertex index within the triangle
    if (vertexInTriangle == 0) {
        vBary = vec2(1.0, 0.0); // First vertex
    } else if (vertexInTriangle == 1) {
        vBary = vec2(0.0, 1.0); // Second vertex
    } else { // vertexInTriangle == 2
        vBary = vec2(0.0, 0.0); // Third vertex
    }

    fragPosition = vertexPosition; // Pass the vertex position to the fragment shader
    fragTexCoord = vertexTexCoord;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
