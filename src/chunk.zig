const std = @import("std");
const rl = @import ("rl.zig");

const MAX_HEIGHTMAP_VALUE = 255;

// chunk width in terms of quads
const CHUNK_SIZE: comptime_int = 64;
const CHUNK_SIZE_VERTICES: comptime_int = CHUNK_SIZE+1;
const MAX_TRIANGLES = CHUNK_SIZE*CHUNK_SIZE*2;
const MAX_VERTICES = MAX_TRIANGLES*2;
const MAX_INDICES = MAX_TRIANGLES*3;

const ChunkMesh = struct {
    vao: c_uint,
    vbo: [2]c_uint,
    ebo: c_uint,
    vertex_count: i32,
};

// TODO MAKE THIS HOLD ALL THE INFORMATION FOR A SINGLE VERTEX
const chunkVertexInformation = packed struct(u32) {
    height: u8,
    texture_id: u12, // total of 4096 textures in a 2048x2048 texture atlas
    normal_pitch: u6,
    normal_yaw: u6,
};

// amount of tiles per side in the tilemap HAS TO BE CHANGED
const TILE_MAP_SIZE: comptime_int = 2;

pub const Chunk = struct {
    allocator: std.mem.Allocator,
    wx: i32,
    wz: i32,
    wpos: rl.Vector3,
    height_map: [CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]u8,
    tile_map: [CHUNK_SIZE][CHUNK_SIZE]u12,
    mesh: ChunkMesh,

    pub fn init(allocator: std.mem.Allocator, wx: i32, wz: i32) Chunk {
        const chunk = Chunk{
            .allocator = allocator,
            .wx = wx,
            .wz = wz,
            .wpos = rl.Vector3{
                .x = @floatFromInt(wx * CHUNK_SIZE),
                .y = 0.0,
                .z = @floatFromInt(wz * CHUNK_SIZE),
            },
            .height_map = std.mem.zeroes([CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]u8),
            .tile_map = std.mem.zeroes([CHUNK_SIZE][CHUNK_SIZE]u12),
            .mesh = undefined,
        };

        // Initialize height_map and tile_map
        // for (0..CHUNK_SIZE_VERTICES) |x| {
        //     for (0..CHUNK_SIZE_VERTICES) |z| {
        //         chunk.height_map[x][z] = @intCast(x + z); // Example height map data
        //         // chunk.tile_map[x][z] = @intCast((x+z)%4);
        //     }
        // }
        return chunk;
    }

    const CustomMesh = struct {
        vao: c_uint,
        vbo: [2]c_uint,
        ebo: c_uint,
        vertex_count: i32,
    };

    // In generateMeshOptimizedCustomIndices:
    pub fn generateMeshOptimizedCustomIndices(self: *Chunk) !void {
        var vertex_info: [MAX_VERTICES]u32 = undefined;
        var indices: [MAX_INDICES]u32 = undefined;        
        var vCounter: usize = 0;
        var iCounter: usize = 0;

        var x: usize = 0;
        while(x < CHUNK_SIZE_VERTICES - 1) : (x+=1) {
            var z: usize = 0;
            while(z < CHUNK_SIZE_VERTICES - 1) : (z+=1) {
                // Pack vertex information
                var info = chunkVertexInformation{
                    .height = self.height_map[x][z],
                    .texture_id = self.tile_map[x][z],
                    .normal_pitch = 32, // Default to straight up
                    .normal_yaw = 0,
                };
                vertex_info[vCounter] = @bitCast(info);
                info.height = self.height_map[x][z+1];
                info.texture_id = self.tile_map[x][z];
                info.normal_pitch = 32;
                info.normal_yaw = 0;
                vertex_info[vCounter + 1] = @bitCast(info);
                info.height = self.height_map[x+1][z];
                info.texture_id = self.tile_map[x][z];
                info.normal_pitch = 32;
                info.normal_yaw = 0;
                vertex_info[vCounter + 2] = @bitCast(info);
                info.height = self.height_map[x+1][z+1];
                info.texture_id = self.tile_map[x][z];
                info.normal_pitch = 32;
                info.normal_yaw = 0;
                vertex_info[vCounter + 3] = @bitCast(info);
                
                // First triangle (top-left, bottom-left, top-right)
                indices[iCounter] = @intCast(vCounter);
                indices[iCounter + 1] = @intCast(vCounter+1);
                indices[iCounter + 2] = @intCast(vCounter+2);
                
                // Second triangle (top-right, bottom-left, bottom-right)
                indices[iCounter + 3] = @intCast(vCounter+2);
                indices[iCounter + 4] = @intCast(vCounter+1);
                indices[iCounter + 5] = @intCast(vCounter+3);
                
                vCounter += 4;
                iCounter += 6;
            }
        }

        var VAO: [1]c_uint = undefined;
        var VBO: [1]c_uint = undefined;
        var EBO: [1]c_uint = undefined;

        rl.glGenVertexArrays(1, &VAO);
        rl.glGenBuffers(1, &VBO);
        rl.glGenBuffers(1, &EBO);

        rl.glBindVertexArray(VAO[0]);

        // Buffer packed vertex data
        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, VBO[0]);
        rl.glBufferData(rl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertex_info)), &vertex_info, rl.GL_STATIC_DRAW);
        rl.glVertexAttribIPointer(0, 1, rl.GL_UNSIGNED_INT, 0, null);
        rl.glEnableVertexAttribArray(0);

        // Buffer indices
        rl.glBindBuffer(rl.GL_ELEMENT_ARRAY_BUFFER, EBO[0]);
        rl.glBufferData(rl.GL_ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), &indices, rl.GL_STATIC_DRAW);

        rl.glBindVertexArray(0);

        self.mesh = ChunkMesh{
            .vao = VAO[0],
            .vbo = [2]c_uint{ VBO[0], 0 },
            .ebo = EBO[0],
            .vertex_count = @intCast(iCounter),
        };
    }

    pub fn render(self: *Chunk, shader: rl.Shader, texture: rl.Texture) void {
        // const matModelView = rl.rlGetMatrixModelview();
        // const matProjection = rl.rlGetMatrixProjection();
        // const matModelViewProjection = rl.MatrixMultiply(matModelView, matProjection);

        _ = texture;
        // // Set up texture
        // const texLoc = rl.GetShaderLocation(shader, "texture0");
        // rl.rlSetUniformSampler(texLoc, texture.id);

        // const mvpLoc = rl.GetShaderLocation(shader, "mvp");
        // rl.SetShaderValueMatrix(shader, mvpLoc, matModelViewProjection);

        // Set up wpos
        const wposLoc = rl.GetShaderLocation(shader, "wpos");
        rl.SetShaderValueV(shader, wposLoc, &self.wpos, rl.SHADER_UNIFORM_VEC3, 1);

        // If VAO not available, set up vertex attributes and indices manually
        if (!rl.rlEnableVertexArray(self.mesh.vao)) {
            // Bind and set up heights (vertex positions)
            rl.glBindBuffer(rl.GL_ARRAY_BUFFER, self.mesh.vbo[0]);
            const vertexLoc = rl.GetShaderLocation(shader, "vertexInfo");
            if (vertexLoc != -1) {
                rl.glVertexAttribPointer(
                    @intCast(vertexLoc), 
                    1, 
                    rl.GL_INT, 
                    rl.GL_FALSE, 
                    0, 
                    null
                );
                rl.glEnableVertexAttribArray(@intCast(vertexLoc));
            }

            // Bind the element buffer object
            rl.glBindBuffer(rl.GL_ELEMENT_ARRAY_BUFFER, self.mesh.ebo);
        }

        rl.glDrawElements(rl.GL_TRIANGLES, @intCast(self.mesh.vertex_count), rl.GL_UNSIGNED_INT, null);
    }

    pub fn deinit(self: *Chunk) void {
        rl.glDeleteBuffers(1, &self.mesh.vbo[0]);
        rl.glDeleteBuffers(1, &self.mesh.ebo);
        rl.glDeleteVertexArrays(1, &self.mesh.vao);
    }
};
