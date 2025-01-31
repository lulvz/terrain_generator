const std = @import("std");
const rl = @import("rl.zig");
const sn = @import("simple-noises");

const chunk = @import("chunk.zig");

const Vec3Padded = packed struct {
    x: f32,
    y: f32,
    z: f32,
    _padding: f32 = 0,
};

pub fn ChunkManager(comptime chunk_amount: comptime_int) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        shader: rl.Shader,
        texture: rl.Texture,
        chunks: std.ArrayList(*chunk.Chunk),

        noise_generator: sn.PerlinNoise2D(f64),

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

        pub fn init(allocator: std.mem.Allocator, seed: u64) !Self {
            var cm = Self{
                .allocator = allocator,
                .shader = rl.LoadShader("resources/terrain_indices_batch.vs", "resources/terrain_indices_batch.fs"),
                .texture = rl.LoadTexture("fd_atlas.png"),
                .chunks = std.ArrayList(*chunk.Chunk).init(allocator),
                
                .noise_generator = sn.PerlinNoise2D(f64).init(seed, 0.03),

                .shared_vertex_info = try allocator.alloc(u32, chunk_amount * chunk.MAX_VERTICES),
                .shared_indices = try allocator.alloc(u32, chunk_amount * chunk.MAX_INDICES),
                .shared_wpos = try allocator.alloc(Vec3Padded, chunk_amount),

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

        pub fn createChunk(self: *Self, dir_path: []const u8, wx: i32, wz: i32) !void {
            if (!(self.shared_vertex_info_idx <= ((chunk_amount * chunk.MAX_VERTICES) - chunk.MAX_VERTICES))) return error.WrongSharedVBOSize;

            // -------------------------- FILE LOADING --------------------------
            const c = try self.allocator.create(chunk.Chunk);

            c.* = chunk.Chunk.init(wx, wz);

            var filename_buffer: [128]u8 = undefined;
            const file_name = try std.fmt.bufPrint(
                &filename_buffer,
                "{s}/chunk_{d}_{d}.dat",
                .{ dir_path, wx, wz }
            );

            // if the chunk doesn't exist yet, generate it from the
            if (!try c.loadChunk(file_name)) {
                c.generateHeightMap(&self.noise_generator);
            }
            // -------------------------- END FILE LOADING --------------------------

            // this uses the fields contained within the chunk to generate the vbo/ebo into the passed slices
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

        // TEMPORARY JUST TO TEST
        pub fn bindData(self: *Self) void {
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

        pub fn render(self: *Self) void {
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

        pub fn writeChunks(self: *Self, dir_path: []const u8) !void {
            // try to create the directory
            try std.fs.cwd().makePath(dir_path);

            for (self.chunks.items) |c| {
                // ---
                var filename_buffer: [128]u8 = undefined;
                const file_name = try std.fmt.bufPrint(
                    &filename_buffer,
                    "{s}/chunk_{d}_{d}.dat",
                    .{ dir_path, c.wx, c.wz }
                );

                try c.saveChunk(file_name);
                // ---
            }
        }

        pub fn deinit(self: *Self) void {
            // write chunks

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
}
