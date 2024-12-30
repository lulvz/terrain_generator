#version 330 core

in vec3 fragPosition; // Position of the vertex passed from the vertex shader
out vec4 finalColor;  // Output color of the fragment

in float tileID;      // Tile ID passed from the vertex shader

uniform sampler2D texture0; // Texture sampler
uniform uint atlasSize

uniform tile

void main() {
    vec2 tileCoords = vec2(mod(tileID, atlasSize), floor(tileID / atlasSize));
    vec2 tileUV = fragPosition.xz / 16.0;
    vec2 uv = (tileCoords + tileUV) / atlasSize;
    vec4 texColor = texture(texture0, fragPosition.xz / 16.0);

    // Set the final fragment color
    finalColor = texColor;
}
