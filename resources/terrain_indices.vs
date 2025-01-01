#version 330 core
layout(location = 0) in int vertexInfo;    // Input info for each vertex
// TODO CHECK IF USING INTS IS FINE FOR THIS
out vec3 fragPosition;                         // Pass to the fragment shader
// out vec2 vBary;
uniform mat4 mvp;

float gridSize = 16.0; // CHUNK_SIZE_VERTICES
float gridSpacing = 1.0; // Distance between vertices

void main() {
        // Calculate quad index and vertex within the quad
    int quadIndex = gl_VertexID / 4; // Each quad has 6 vertices (2 triangles)
    int vertexInQuad = gl_VertexID % 4; // Vertex index within the quad

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
        x = (mod(float(quadIndex), (gridSize)) + 1.0) * gridSpacing; // Sixth vertex
        z = (floor(float(quadIndex) / (gridSize)) + 1.0) * gridSpacing;
    }
    // Unpack vertex information
    uint height = uint(vertexInfo & 0xFF);
    uint textureId = uint((vertexInfo >> 8) & 0xFFF);
    uint pitch = uint((vertexInfo >> 20) & 0x3F);
    uint yaw = uint((vertexInfo >> 26) & 0x3F);
    float heightf = float(height);
    
    // Calculate barycentric coordinates
    // int vertexInTriangle = gl_VertexID % 3; // Vertex index within the triangle
    // if (vertexInTriangle == 0) {
    //     vBary = vec2(1.0, 0.0); // First vertex
    // } else if (vertexInTriangle == 1) {
    //     vBary = vec2(0.0, 1.0); // Second vertex
    // } else { // vertexInTriangle == 2
    //     vBary = vec2(0.0, 0.0); // Third vertex
    // }
    
    // Construct the vertex position using the input height
    vec3 vertexPosition = vec3(x, heightf, z);
    
    // Pass data to fragment shader
    fragPosition = vertexPosition;
    
    // Output final position
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}