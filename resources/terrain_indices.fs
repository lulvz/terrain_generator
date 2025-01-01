#version 330 core

in vec3 fragPosition; // Position of the vertex passed from the vertex shader
// in vec2 vBary;
out vec4 finalColor;  // Output color of the fragment

// in float tileID;      // Tile ID passed from the vertex shader

uniform sampler2D texture0; // Texture sampler
// uniform uint atlasSize

float barycentric(vec2 vBC, float width)
{
    vec3 bary = vec3(vBC.x, vBC.y, 1.0 - vBC.x - vBC.y);
    vec3 d = fwidth(bary);
    vec3 a3 = smoothstep(d * (width - 0.5), d * (width + 0.5), bary);
    return min(min(a3.x, a3.y), a3.z);
}

void main() {
    // vec2 tileCoords = vec2(mod(tileID, atlasSize), floor(tileID / atlasSize));
    // vec2 tileUV = fragPosition.xz / 16.0;
    // vec2 uv = (tileCoords + tileUV) / atlasSize;
    vec4 texColor = texture(texture0, fragPosition.xz / 16.0);

    // Set the final fragment color
    finalColor = texColor;
    // finalColor = texture(texture0, fragTexCoord);

    // wireframe mode
    // finalColor.rgb *= 0.5;
    // finalColor.rgb += vec3(1.0 - barycentric(vBary, 1.0));

}
