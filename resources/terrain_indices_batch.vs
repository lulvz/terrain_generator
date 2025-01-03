#version 330 core
layout(location = 0) in int vertexInfo;    // Input info for each vertex
uniform mat4 mvp;

layout (std140) uniform ChunkData {
    vec3 wpos[40*40];
};

out vec3 fragPosition;                         // Pass to the fragment shader
// out vec2 vBary;


int gridSize = 64;

void main() {
    // Calculate quad index and vertex within the quad
    int quadIndex = (gl_VertexID / 4) % (gridSize*gridSize); // Each quad has 4 vertices
    int vertexInQuad = gl_VertexID % 4; // Vertex index within the quad

    // Extract grid x and z positions based on the quad layout
    int x, z;

    if (vertexInQuad == 0) {
        x = quadIndex % gridSize; // First vertex of quad
        z = quadIndex / gridSize;
    } else if (vertexInQuad == 1) {
        x = quadIndex % gridSize; // Second vertex
        z = (quadIndex / gridSize) + 1;
    } else if (vertexInQuad == 2) {
        x = (quadIndex % gridSize) + 1; // Third vertex
        z = quadIndex / gridSize;
    } else if (vertexInQuad == 3) {
        x = (quadIndex % gridSize) + 1; // Sixth vertex
        z = (quadIndex / gridSize) + 1;
    }
    // Unpack vertex information
    float heightf = float(vertexInfo & 0xFF);
    uint textureId = uint((vertexInfo >> 8) & 0xFFF);
    uint pitch = uint((vertexInfo >> 20) & 0x3F);
    uint yaw = uint((vertexInfo >> 26) & 0x3F);
    // float heightf = float(height);
    
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
    vec3 vertexPosition = wpos[gl_VertexID/(gridSize*gridSize*4)] + vec3(float(x), heightf, float(z));
    
    // Pass data to fragment shader
    fragPosition = vertexPosition;
    
    // Output final position
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}