const std = @import("std");
const rl = @import("rl.zig");

const chunk = @import("chunk.zig");

const CHUNK_AMOUNT = 2*2;

const Vec3Padded = struct {
    x: f32,
    y: f32,
    z: f32,
    _padding: f32 = 0,
};

pub const ChunkManager = struct {
    allocator: std.mem.Allocator,
    shader: rl.Shader,
    texture: rl.Texture,
    chunks: std.ArrayList(*chunk.Chunk),

    shared_vertex_info: []u32,
    shared_indices: []u32,
    shared_wpos: []Vec3Padded,

    shared_vertex_info_idx: usize,
    shared_indices_idx: usize,
    shared_wpos_idx: usize,

    VAO: c_uint,
    VBO: c_uint,
    EBO: c_uint,
    UBO: c_uint,

    pub fn init(allocator: std.mem.Allocator) !ChunkManager {
        var cm = ChunkManager{
            .allocator = allocator,
            .shader = rl.LoadShader("resources/terrain_indices_batch.vs", "resources/terrain_indices_batch.fs"),
            .texture = rl.LoadTexture("fd_atlas.png"),
            .chunks = std.ArrayList(*chunk.Chunk).init(allocator),

            .shared_vertex_info = try allocator.alloc(u32, CHUNK_AMOUNT * chunk.MAX_VERTICES),
            .shared_indices = try allocator.alloc(u32, CHUNK_AMOUNT * chunk.MAX_INDICES),
            .shared_wpos = try allocator.alloc(Vec3Padded, CHUNK_AMOUNT),

            .shared_vertex_info_idx = 0,
            .shared_indices_idx = 0,
            .shared_wpos_idx = 0,

            .VAO = undefined,
            .VBO= undefined,
            .EBO = undefined,
            .UBO = undefined,
        };

        rl.glGenVertexArrays(1, &cm.VAO);
        rl.glGenBuffers(1, &cm.VBO);
        rl.glGenBuffers(1, &cm.EBO);
        rl.glGenBuffers(1, &cm.UBO);

        return cm;
    }

    // wy has the same scale as the height value in a 
    pub fn createChunk(self: *ChunkManager, wx: i32, wy: i32, wz: i32) !void {
        if(self.shared_vertex_info_idx <= ((CHUNK_AMOUNT * chunk.MAX_VERTICES) - chunk.MAX_VERTICES)) {
            const c = try self.allocator.create(chunk.Chunk);
                
            const heightf: f32 = @floatFromInt(wy);
            const height_scaled: f32 = (heightf / chunk.MAX_HEIGHTMAP_VALUE) * 64.0;
            c.* = chunk.Chunk.init(rl.Vector3{.x = @floatFromInt(wx*chunk.CHUNK_SIZE), .y = height_scaled, .z = @floatFromInt(wz*chunk.CHUNK_SIZE)});
            try c.generateMesh(
                self.shared_vertex_info[self.shared_vertex_info_idx..self.shared_vertex_info_idx+chunk.MAX_VERTICES],
                self.shared_indices[self.shared_indices_idx..self.shared_indices_idx+chunk.MAX_INDICES]
            );
            // Apply the vertex offset to each index in the chunk
            for (self.shared_indices[self.shared_indices_idx..self.shared_indices_idx+chunk.MAX_INDICES], 0..) |index, idx| {
                self.shared_indices[self.shared_indices_idx..self.shared_indices_idx+chunk.MAX_INDICES][idx] = @intCast(index + self.shared_vertex_info_idx);
            }
            self.shared_wpos[self.shared_wpos_idx] = .{.x = c.wpos.x, .y = c.wpos.y, .z = c.wpos.z};

            self.shared_vertex_info_idx += chunk.MAX_VERTICES;
            self.shared_indices_idx += chunk.MAX_INDICES;
            self.shared_wpos_idx += 1;

            try self.chunks.append(c);
        }
    }

    // TEMPORARY JUST TO TEST
    pub fn bindData(self: *ChunkManager) void {
        rl.glBindVertexArray(self.VAO);

        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, self.VBO);
        rl.glBufferData(rl.GL_ARRAY_BUFFER, @intCast(self.shared_vertex_info_idx * @sizeOf(u32)), self.shared_vertex_info.ptr, rl.GL_DYNAMIC_DRAW);
        rl.glVertexAttribIPointer(0, 1, rl.GL_UNSIGNED_INT, 0, null);
        rl.glEnableVertexAttribArray(0);

        rl.glBindBuffer(rl.GL_ELEMENT_ARRAY_BUFFER, self.EBO);
        rl.glBufferData(rl.GL_ELEMENT_ARRAY_BUFFER, @intCast(self.shared_indices_idx * @sizeOf(u32)), self.shared_indices.ptr, rl.GL_DYNAMIC_DRAW);


        rl.glBindBuffer(rl.GL_UNIFORM_BUFFER, self.UBO);
        rl.glBufferData(rl.GL_UNIFORM_BUFFER, @intCast(self.shared_wpos_idx * @sizeOf(Vec3Padded)), self.shared_wpos.ptr, rl.GL_DYNAMIC_DRAW);
        rl.glBindBufferBase(rl.GL_UNIFORM_BUFFER, 0, self.UBO);

        rl.glBindVertexArray(0);
        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, 0);
        rl.glBindBuffer(rl.GL_ELEMENT_ARRAY_BUFFER, 0);
        rl.glBindBuffer(rl.GL_UNIFORM_BUFFER, 0);
    }

    pub fn render(self: *ChunkManager) void {
        rl.rlEnableShader(self.shader.id);

        const texLoc = rl.GetShaderLocation(self.shader, "texture0");
        rl.rlSetUniformSampler(texLoc, self.texture.id);

        const matModelView = rl.rlGetMatrixModelview();
        const matProjection = rl.rlGetMatrixProjection();
        const matModelViewProjection = rl.MatrixMultiply(matModelView, matProjection);

        const mvpLoc = rl.GetShaderLocation(self.shader, "mvp");
        rl.SetShaderValueMatrix(self.shader, mvpLoc, matModelViewProjection);

        // If VAO not available, set up vertex attributes and indices manually
        if (!rl.rlEnableVertexArray(self.VAO)) {
            // Bind and set up heights (vertex positions)
            rl.glBindBuffer(rl.GL_ARRAY_BUFFER, self.VBO);
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
            rl.glBindBuffer(rl.GL_ELEMENT_ARRAY_BUFFER, self.EBO);

            rl.glBindBuffer(rl.GL_UNIFORM_BUFFER, self.UBO);
        }

        rl.glDrawElements(rl.GL_TRIANGLES, @intCast(self.shared_indices_idx), rl.GL_UNSIGNED_INT, null);

        rl.rlDisableVertexArray();
        rl.rlDisableVertexBuffer();
        rl.rlDisableVertexBufferElement();

        // Disable shader program
        rl.rlDisableShader();
    }

    pub fn deinit(self: *ChunkManager) void {
        for (self.chunks.items) |c| {
            c.deinit();
            self.allocator.destroy(c);
        }
        self.chunks.deinit();
        rl.UnloadShader(self.shader);
        rl.UnloadTexture(self.texture);
        self.allocator.free(self.shared_vertex_info);
        self.allocator.free(self.shared_indices);

        rl.glDeleteBuffers(1, &self.VBO);
        rl.glDeleteBuffers(1, &self.EBO);
        rl.glDeleteVertexArrays(1, &self.VAO);

    }
};
