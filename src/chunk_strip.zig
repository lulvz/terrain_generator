const std = @import("std");
const rl = @import ("rl.zig");

const MAX_HEIGHTMAP_VALUE = 255.0;

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

// amount of tiles per side in the tilemap
const TILE_MAP_SIZE: comptime_int = 2;

pub const Chunk = struct {
    allocator: std.mem.Allocator,
    wx: i32,
    wz: i32,
    wpos: rl.Vector3,
    height_map: [CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]f32, // TODO make this load from this file: chunk_%d_%d.bin
    tile_map: [CHUNK_SIZE][CHUNK_SIZE]u8, // TODO CHECK IF THIS IS FINE
    mesh: ChunkMesh,
    shader: rl.Shader,
    texture: rl.Texture,

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
            .height_map = std.mem.zeroes([CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]f32),
            .tile_map = std.mem.zeroes([CHUNK_SIZE][CHUNK_SIZE]u8),
            .model = undefined,
            .mesh = undefined,
            .shader = undefined,
            .texture = undefined,
        };

        const shader = rl.LoadShader("resources/terrain_strip.vs", "resources/terrain_strip.fs");
        chunk.shader = shader;

        const texture = rl.LoadTexture("atlas_2x2.png");
        chunk.texture = texture;

        chunk.model = undefined;
        for (0..CHUNK_SIZE) |x| {
            for (0..CHUNK_SIZE) |z| {
                chunk.tile_map[x][z] = @intCast((x+z)%4);
                // chunk.tile_map[x][z] = 2;
            }
        } 

        // Example height map with a gradient
        // for (0..CHUNK_SIZE_VERTICES) |x| {
        //     for (0..CHUNK_SIZE_VERTICES) |z| {
        //         chunk.height_map[x][z] = MAX_HEIGHTMAP_VALUE*@as(f32, @floatFromInt(x + z)) /  @as(f32, @floatFromInt(CHUNK_SIZE));
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

    // 20 by 20 chunks -> 75 to 82 fps
    pub fn generateMeshOptimizedCustomStrip(self: *Chunk) !void {
        // For a strip, we need (width + 1) * 2 vertices per row
        const vertices_per_row = CHUNK_SIZE_VERTICES * 2;
        const total_vertices = vertices_per_row * CHUNK_SIZE;
        
        var heights: [total_vertices]f32 = std.mem.zeroes([total_vertices]f32);
        var texcoords: [total_vertices * 2]f32 = std.mem.zeroes([total_vertices * 2]f32);
        var vCounter: usize = 0;
        var tcCounter: usize = 0;

        // Generate vertices row by row
        var z: usize = 0;
        while (z < CHUNK_SIZE_VERTICES - 1) : (z += 1) {
            // For each column, generate two vertices (bottom and top)
            var x: usize = 0;
            while (x < CHUNK_SIZE_VERTICES) : (x += 1) {
                // Bottom vertex
                heights[vCounter] = self.height_map[x][z+1];
                vCounter += 1;

                // Top vertex
                heights[vCounter] = self.height_map[x][z];
                vCounter += 1;

                // Texture coordinates calculation (corrected)
                const uvTileSize = 1.0 / @as(f32, TILE_MAP_SIZE);
                const tileIndex = if (x < CHUNK_SIZE and z < CHUNK_SIZE) 
                    self.tile_map[x][z] 
                else 
                    self.tile_map[CHUNK_SIZE-1][CHUNK_SIZE-1];

                const uvXBase = @as(f32, @floatFromInt(tileIndex % TILE_MAP_SIZE)) * uvTileSize;
                const uvYBase = @as(f32, @floatFromInt(tileIndex / TILE_MAP_SIZE)) * uvTileSize;

                // Bottom vertex UV
                texcoords[tcCounter] = uvXBase + (@as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(CHUNK_SIZE_VERTICES))) * uvTileSize;
                texcoords[tcCounter + 1] = uvYBase + uvTileSize - (@as(f32, @floatFromInt(z+1)) / @as(f32, @floatFromInt(CHUNK_SIZE_VERTICES))) * uvTileSize;
                tcCounter += 2;

                // Top vertex UV
                texcoords[tcCounter] = uvXBase + (@as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(CHUNK_SIZE_VERTICES))) * uvTileSize;
                texcoords[tcCounter + 1] = uvYBase + uvTileSize - (@as(f32, @floatFromInt(z)) / @as(f32, @floatFromInt(CHUNK_SIZE_VERTICES))) * uvTileSize;
                tcCounter += 2;
            }
        }

        var VAO: [1]c_uint = undefined;
        var VBO: [2]c_uint = undefined;

        rl.glGenVertexArrays(1, &VAO);
        rl.glGenBuffers(2, &VBO);
        rl.glBindVertexArray(VAO[0]);

        // Buffer heights data
        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, VBO[0]);
        rl.glBufferData(rl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(heights)), &heights, rl.GL_STATIC_DRAW);
        rl.glVertexAttribPointer(0, 1, rl.GL_FLOAT, rl.GL_FALSE, @sizeOf(f32), null);
        rl.glEnableVertexAttribArray(0);

        // Buffer texcoords data
        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, VBO[1]);
        rl.glBufferData(rl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(texcoords)), &texcoords, rl.GL_STATIC_DRAW);
        rl.glVertexAttribPointer(1, 2, rl.GL_FLOAT, rl.GL_FALSE, 2 * @sizeOf(f32), null);
        rl.glEnableVertexAttribArray(1);

        rl.glBindVertexArray(0);

        self.mesh = ChunkMesh{
            .vao = VAO[0],
            .vbo = VBO,
            .ebo = undefined,
            .vertex_count = @intCast(total_vertices),
        };
    }

    // TODO cleanup thsi function
    pub fn renderCustomMeshStrip(self: *Chunk) void {
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

        // If VAO not available, set up vertex attributes manually
        if (!rl.rlEnableVertexArray(self.mesh.vao)) {
            // Bind and set up heights (vertex positions)
            rl.glBindBuffer(rl.GL_ARRAY_BUFFER, self.mesh.vbo[0]);
            const vertexLoc = rl.GetShaderLocation(self.shader, "vertexPosition");
            if (vertexLoc != -1) {
                rl.glVertexAttribPointer(
                    @intCast(vertexLoc), 
                    1, 
                    rl.GL_FLOAT, 
                    rl.GL_FALSE, 
                    0, 
                    null
                );
                rl.glEnableVertexAttribArray(@intCast(vertexLoc));
            }

            // Bind and set up texcoords
            rl.glBindBuffer(rl.GL_ARRAY_BUFFER, self.mesh.vbo[1]);
            const texcoordLoc = rl.GetShaderLocation(self.shader, "vertexTexCoord");
            if (texcoordLoc != -1) {
                rl.glVertexAttribPointer(
                    @intCast(texcoordLoc), 
                    2, 
                    rl.GL_FLOAT, 
                    rl.GL_FALSE, 
                    0, 
                    null
                );
                rl.glEnableVertexAttribArray(@intCast(texcoordLoc));
            }
        }
        
        // Draw the mesh
        rl.glDrawArrays(rl.GL_TRIANGLE_STRIP, 0, self.mesh.vertex_count);

        // Cleanup state
        if (texLoc != -1) {
            rl.rlDisableTexture();
        }
        
        rl.rlDisableVertexArray();
        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, 0);
        
        rl.EndShaderMode(); // TODO CHECK IF THIS IS NEEDED TO RENDER (PROBABLY NOT)

        // Restore matrices
        rl.rlSetMatrixModelview(matView); // TODO CHEK IF THIS IS NEEDED TO RENDER (PROBABLY NOT)
        rl.rlSetMatrixProjection(matProjection);
    }

    pub fn deinit(self: *Chunk) void {
        _ = self;
        // rl.UnloadModel(self.model);
    }
};
