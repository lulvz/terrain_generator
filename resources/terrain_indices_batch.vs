#version 330 core
layout(location = 0) in ivec2 vertexInfo;
uniform mat4 mvp;
layout (std140) uniform ChunkData {
    vec3 wpos[2*2];
};
out vec3 fragPosition;
out vec2 fragTexCoord;  // Added output for texture coordinates

const int gridSize = 64;
const float atlasSize = 64;  // Total size of texture atlas in tiles per side
const float normalizedTextureSize = 1/atlasSize;  // Size of one texture in normalized coordinates

void main() {
    int vertexInQuad = gl_VertexID & 3;
    int quadIndex = (gl_VertexID >> 2) & (gridSize*gridSize - 1);
    int x, z;
    float texU, texV;  // Texture coordinates within a single tile
    
    // Calculate vertex position and texture coordinates based on vertex position in quad
    if (vertexInQuad == 0) {
        x = quadIndex % gridSize;
        z = quadIndex / gridSize;
        texU = 0.0;
        texV = 0.0;
    } else if (vertexInQuad == 1) {
        x = quadIndex % gridSize;
        z = (quadIndex / gridSize) + 1;
        texU = 0.0;
        texV = 1.0;
    } else if (vertexInQuad == 2) {
        x = (quadIndex % gridSize) + 1;
        z = quadIndex / gridSize;
        texU = 1.0;
        texV = 0.0;
    } else {  // vertexInQuad == 3
        x = (quadIndex % gridSize) + 1;
        z = (quadIndex / gridSize) + 1;
        texU = 1.0;
        texV = 1.0;
    }
    
    // Unpack vertex information
    float heightf = float(vertexInfo & 0xFF);
    float height_scaled = (heightf / 255.0) * 64.0;
    uint textureId = uint((vertexInfo >> 8) & 0xFFF);
    uint pitch = uint((vertexInfo >> 20) & 0x3F);
    uint yaw = uint((vertexInfo >> 26) & 0x3F);
    
    // Calculate texture atlas coordinates
    float tileX = float(textureId % uint(atlasSize));
    float tileY = float(textureId / uint(atlasSize));
    
    // Calculate final texture coordinates
    vec2 tileOffset = vec2(tileX, tileY) * normalizedTextureSize;
    fragTexCoord = tileOffset + vec2(texU, texV) * normalizedTextureSize;
    
    // Construct the vertex position using the input height
    vec3 vertexPosition = wpos[gl_VertexID/(gridSize*gridSize*4)] + vec3(float(x), height_scaled, float(z));
    
    // Pass data to fragment shader
    fragPosition = vertexPosition;
    
    // Output final position
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}