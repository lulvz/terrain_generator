const std = @import("std");
const rl = @import ("rl.zig");

const MAX_HEIGHTMAP_VALUE = 255;

// chunk width in terms of quads
const CHUNK_SIZE: comptime_int = 16;
const CHUNK_SIZE_VERTICES: comptime_int = CHUNK_SIZE+1;
const MAX_TRIANGLES = CHUNK_SIZE*CHUNK_SIZE*2;
const MAX_INDICES = (CHUNK_SIZE_VERTICES - 1) * (CHUNK_SIZE_VERTICES - 1) * 6;

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
    height_map: [CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]u8, // TODO make this load from this file: chunk_%d_%d.bin
    tile_map: [CHUNK_SIZE][CHUNK_SIZE]u12,
    mesh: ChunkMesh,
    shader: rl.Shader,
    texture: rl.Texture,

    packed_vertex_information: [CHUNK_SIZE_VERTICES*CHUNK_SIZE_VERTICES]u32,

    pub fn init(allocator: std.mem.Allocator, wx: i32, wz: i32) Chunk {
        var chunk = Chunk {
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
            .shader = undefined,
            .texture = undefined,
            .packed_vertex_information = undefined,
        };

        const shader = rl.LoadShader("resources/terrain_indices.vs", "resources/terrain_indices.fs");
        chunk.shader = shader;

        const texture = rl.LoadTexture("atlas_2x2.png");
        chunk.texture = texture;

        for (0..CHUNK_SIZE) |x| {
            for (0..CHUNK_SIZE) |z| {
                chunk.tile_map[x][z] = @intCast((x+z)%4);
                // chunk.tile_map[x][z] = 2;
            }
        } 

        var x: usize = 0;

        while (x < CHUNK_SIZE_VERTICES) : (x += 1) {
            var z: usize = 0;
            while (z < CHUNK_SIZE_VERTICES) : (z += 1) {
                // Example: Using a simple calculation for the height map
                chunk.height_map[x][z] = @intCast(x + z); // Ensure proper casting to u8
            }
        }

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
        var vertex_info: [MAX_TRIANGLES*2]u32 = undefined;
        var indices: [MAX_TRIANGLES*3]u32 = undefined;        
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

    pub fn renderCustomMeshIndices(self: *Chunk) void {
        rl.BeginShaderMode(self.shader);
        
        // Get current matrices state
        const matView = rl.rlGetMatrixModelview();
        const matProjection = rl.rlGetMatrixProjection();
        
        // Create and combine transformation matrices
        const matModel = rl.MatrixTranslate(self.wpos.x, self.wpos.y, self.wpos.z);
        const matModelView = rl.MatrixMultiply(matModel, matView);
        const matMVP = rl.MatrixMultiply(matModelView, matProjection);

        // Set shader uniforms
        const mvpLoc = rl.GetShaderLocation(self.shader, "mvp");
        if (mvpLoc != -1) {
            rl.SetShaderValueMatrix(self.shader, mvpLoc, matMVP);
        }

        // Set up texture
        const texLoc = rl.GetShaderLocation(self.shader, "texture0");
        if (texLoc != -1) {
            rl.SetShaderValue(self.shader, texLoc, &[_]i32{0}, rl.SHADER_UNIFORM_INT);
            rl.rlActiveTextureSlot(0);
            rl.rlEnableTexture(self.texture.id);
        }

        // If VAO not available, set up vertex attributes and indices manually
        if (!rl.rlEnableVertexArray(self.mesh.vao)) {
            // Bind and set up heights (vertex positions)
            rl.glBindBuffer(rl.GL_ARRAY_BUFFER, self.mesh.vbo[0]);
            const vertexLoc = rl.GetShaderLocation(self.shader, "vertexInfo");
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
        
        // Draw the mesh using indices
        rl.glDrawElements(
            rl.GL_TRIANGLES,
            @intCast(self.mesh.vertex_count),
            rl.GL_UNSIGNED_INT,
            null
        );

        // Cleanup state
        if (texLoc != -1) {
            rl.rlDisableTexture();
        }
        
        rl.rlDisableVertexArray();
        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, 0);
        rl.glBindBuffer(rl.GL_ELEMENT_ARRAY_BUFFER, 0);
        
        rl.EndShaderMode();
        // Restore matrices
        rl.rlSetMatrixModelview(matView);
        rl.rlSetMatrixProjection(matProjection);    
    }

    pub fn deinit(self: *Chunk) void {
        _ = self;
    }
};
