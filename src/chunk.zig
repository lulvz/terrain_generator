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
    model: rl.Model,
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

        const shader = rl.LoadShader("resources/terrain.vs", "resources/terrain.fs");
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
        vertex_count: i32,
    };

    pub fn generateMeshOptimizedCustom(self: *Chunk) !void {
        var heights: [MAX_TRIANGLES*3]f32 = std.mem.zeroes([MAX_TRIANGLES*3]f32);
        var texcoords: [MAX_TRIANGLES*3*2]f32 = std.mem.zeroes([MAX_TRIANGLES*3*2]f32);
        var vCounter: usize = 0;
        var tcCounter: usize = 0;
        var x: usize = 0;

        while(x < CHUNK_SIZE_VERTICES-1) : (x+=1) {
            var z: usize = 0;
            while(z < CHUNK_SIZE_VERTICES-1) : (z+=1) {
                // One triangle - 3 heights
                heights[vCounter] = self.height_map[x][z];
                heights[vCounter + 1] = self.height_map[x][z+1];
                heights[vCounter + 2] = self.height_map[x+1][z];

                // Another triangle - 3 heights
                heights[vCounter + 3] = self.height_map[x+1][z];
                heights[vCounter + 4] = self.height_map[x][z+1];
                heights[vCounter + 5] = self.height_map[x+1][z+1];
                vCounter += 6;

                // Calculate texture coordinates
                const uvTileSize = 1.0 / @as(f32, TILE_MAP_SIZE);
                const tileIndex = self.tile_map[x][z];
                const uvXBase = @as(f32, @floatFromInt(tileIndex % TILE_MAP_SIZE)) * uvTileSize;
                const uvYBase = @as(f32, @floatFromInt(tileIndex / TILE_MAP_SIZE)) * uvTileSize;

                // First triangle texcoords
                texcoords[tcCounter] = uvXBase;
                texcoords[tcCounter + 1] = uvYBase;

                texcoords[tcCounter + 2] = uvXBase;
                texcoords[tcCounter + 3] = uvYBase + uvTileSize;

                texcoords[tcCounter + 4] = uvXBase + uvTileSize;
                texcoords[tcCounter + 5] = uvYBase;

                // Second triangle texcoords
                texcoords[tcCounter + 6] = uvXBase + uvTileSize;
                texcoords[tcCounter + 7] = uvYBase;

                texcoords[tcCounter + 8] = uvXBase;
                texcoords[tcCounter + 9] = uvYBase + uvTileSize;

                texcoords[tcCounter + 10] = uvXBase + uvTileSize;
                texcoords[tcCounter + 11] = uvYBase + uvTileSize;
                tcCounter += 12;
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
            .vertex_count = @intCast(MAX_TRIANGLES * 3),
        };
    }

    // generates a mesh that uses the vertex shader to calculate vertex xz positions
    pub fn generateMeshOptimized(self: *Chunk) !void {
        var heights: [MAX_TRIANGLES*3]f32 = std.mem.zeroes([MAX_TRIANGLES*3]f32);
        var vCounter: usize = 0;
        var x: usize = 0;

        var mesh: rl.Mesh = .{};
        mesh.triangleCount = MAX_TRIANGLES;
        mesh.vertexCount = MAX_TRIANGLES*3;

        mesh.texcoords = @ptrCast(@alignCast(rl.RL_MALLOC(@as(c_ulong, @intCast(mesh.vertexCount*2*@sizeOf(f32))))));
        var tcCounter: usize = 0;

        while(x < CHUNK_SIZE_VERTICES-1) : (x+=1) {
            var z: usize = 0;
            while(z < CHUNK_SIZE_VERTICES-1) : (z+=1) {
                // one triangle - 3 heights
                heights[vCounter] = self.height_map[x][z];
                heights[vCounter + 1] = self.height_map[x][z+1];
                heights[vCounter + 2] = self.height_map[x+1][z];

                // Another triangle - 3 heghts 
                heights[vCounter + 3] = self.height_map[x+1][z];
                heights[vCounter + 4] = self.height_map[x][z+1];
                heights[vCounter + 5] = self.height_map[x+1][z+1];
                vCounter += 6;

                // Fill texcoords array with data
                // --------------------------------------------------------------
                const uvTileSize = 1.0 / @as(f32, TILE_MAP_SIZE);

                // Compute the UV base offset for the tile at (x, z)
                const tileIndex = self.tile_map[x][z];
                const uvXBase = @as(f32, @floatFromInt(tileIndex % TILE_MAP_SIZE)) * uvTileSize;
                const uvYBase = @as(f32, @floatFromInt(tileIndex / TILE_MAP_SIZE)) * uvTileSize;

                // Fill texcoords array with adjusted UV coordinates
                mesh.texcoords[tcCounter] = uvXBase;
                mesh.texcoords[tcCounter + 1] = uvYBase;

                mesh.texcoords[tcCounter + 2] = uvXBase;
                mesh.texcoords[tcCounter + 3] = uvYBase + uvTileSize;

                mesh.texcoords[tcCounter + 4] = uvXBase + uvTileSize;
                mesh.texcoords[tcCounter + 5] = uvYBase;

                mesh.texcoords[tcCounter + 6] = mesh.texcoords[tcCounter + 4];
                mesh.texcoords[tcCounter + 7] = mesh.texcoords[tcCounter + 5];

                mesh.texcoords[tcCounter + 8] = mesh.texcoords[tcCounter + 2];
                mesh.texcoords[tcCounter + 9] = mesh.texcoords[tcCounter + 3];

                mesh.texcoords[tcCounter + 10] = uvXBase + uvTileSize;
                mesh.texcoords[tcCounter + 11] = uvYBase + uvTileSize;
                tcCounter += 12; // 6 texcoords, 12 floats
            }
        }

        var VAO: [1]c_uint = undefined;
        var VBO: [2]c_uint = undefined;

        rl.glGenVertexArrays(1, &VAO);
        rl.glGenBuffers(2, &VBO);

        rl.glBindVertexArray(VAO[0]);

        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, VBO[0]);
        rl.glBufferData(rl.GL_ARRAY_BUFFER, @sizeOf([MAX_TRIANGLES*3]f32), &heights, rl.GL_STATIC_DRAW);
        rl.glVertexAttribPointer(0, 1, rl.GL_FLOAT, rl.GL_FALSE, @sizeOf(f32), null);
        rl.glEnableVertexAttribArray(0);

        // Bind texcoords data
        rl.glBindBuffer(rl.GL_ARRAY_BUFFER, VBO[1]);
        rl.glBufferData(rl.GL_ARRAY_BUFFER, mesh.vertexCount * 2 * @sizeOf(f32), mesh.texcoords, rl.GL_STATIC_DRAW);
        rl.glVertexAttribPointer(1, 2, rl.GL_FLOAT, rl.GL_FALSE, 2 * @sizeOf(f32), null); // 2 floats per texcoord (U, V)
        rl.glEnableVertexAttribArray(1);

        rl.glBindVertexArray(0);

        mesh.vaoId = VAO[0];
        mesh.vboId = VBO[0];
        mesh.colors = null;

        // rl.UploadMesh(&mesh, false);
        self.model = rl.LoadModelFromMesh(mesh);

        const shader = rl.LoadShader("resources/terrain.vs", "resources/terrain.fs");
        self.model.materials[0].shader = shader;

        const texture = rl.LoadTexture("atlas_2x2.png");
        self.model.materials[0].maps[rl.MATERIAL_MAP_DIFFUSE].texture = texture;
    }

    pub fn generateMesh(self: *Chunk, size: rl.Vector3) !void {
        var mesh: rl.Mesh = .{};

        mesh.triangleCount = MAX_TRIANGLES;
        mesh.vertexCount = MAX_TRIANGLES*3;

        // mesh.vertices = (float *)RL_MALLOC(mesh.vertexCount*3*sizeof(float));
        // mesh.normals = (float *)RL_MALLOC(mesh.vertexCount*3*sizeof(float));
        // mesh.texcoords = (float *)RL_MALLOC(mesh.vertexCount*2*sizeof(float));
        mesh.vertices = @ptrCast(@alignCast(rl.RL_MALLOC(@as(c_ulong, @intCast(mesh.vertexCount*3*@sizeOf(f32))))));
        // mesh.normals = @ptrCast(@alignCast(rl.RL_MALLOC(@as(c_ulong, @intCast(mesh.vertexCount*3*@sizeOf(f32))))));
        mesh.texcoords = @ptrCast(@alignCast(rl.RL_MALLOC(@as(c_ulong, @intCast(mesh.vertexCount*2*@sizeOf(f32))))));
        mesh.colors = null;

        var vCounter: usize = 0;
        var tcCounter: usize = 0;
        // var nCounter: usize = 0;

        // var vA: rl.Vector3 = .{.x=0,.y=0,.z=0};
        // var vB: rl.Vector3 = .{.x=0,.y=0,.z=0};
        // var vC: rl.Vector3 = .{.x=0,.y=0,.z=0};
        // var vN: rl.Vector3 = .{.x=0,.y=0,.z=0};

        const scaleFactor: rl.Vector3 = .{ .x = size.x/CHUNK_SIZE, .y = size.y/MAX_HEIGHTMAP_VALUE, .z = size.z/CHUNK_SIZE };

        var x: usize = 0;
        while(x < CHUNK_SIZE_VERTICES-1) : (x+=1) {
            var z: usize = 0;
            while(z < CHUNK_SIZE_VERTICES-1) : (z+=1) {
                // one triangle - 3 vertex
                mesh.vertices[vCounter] = @as(f32, @floatFromInt(x))*scaleFactor.x;
                mesh.vertices[vCounter + 1] = self.height_map[x][z]*scaleFactor.y;
                mesh.vertices[vCounter + 2] = @as(f32, @floatFromInt(z))*scaleFactor.z;

                mesh.vertices[vCounter + 3] = @as(f32, @floatFromInt(x))*scaleFactor.x;
                mesh.vertices[vCounter + 4] = self.height_map[x][z+1]*scaleFactor.y;
                mesh.vertices[vCounter + 5] = @as(f32, @floatFromInt(z+1))*scaleFactor.z;

                mesh.vertices[vCounter + 6] = @as(f32, @floatFromInt(x+1))*scaleFactor.x;
                mesh.vertices[vCounter + 7] = self.height_map[x+1][z]*scaleFactor.y;
                mesh.vertices[vCounter + 8] = @as(f32, @floatFromInt(z))*scaleFactor.z;

                // Another triangle - 3 vertex
                mesh.vertices[vCounter + 9] = mesh.vertices[vCounter + 6];
                mesh.vertices[vCounter + 10] = mesh.vertices[vCounter + 7];
                mesh.vertices[vCounter + 11] = mesh.vertices[vCounter + 8];

                mesh.vertices[vCounter + 12] = mesh.vertices[vCounter + 3];
                mesh.vertices[vCounter + 13] = mesh.vertices[vCounter + 4];
                mesh.vertices[vCounter + 14] = mesh.vertices[vCounter + 5];

                mesh.vertices[vCounter + 15] = @as(f32, @floatFromInt(x+1))*scaleFactor.x;
                mesh.vertices[vCounter + 16] = self.height_map[x+1][z+1]*scaleFactor.y;
                mesh.vertices[vCounter + 17] = @as(f32, @floatFromInt(z+1))*scaleFactor.z;
                vCounter += 18;     // 6 vertex, 18 floats
                
                // Fill texcoords array with data
                // --------------------------------------------------------------
                const uvTileSize = 1.0 / @as(f32, TILE_MAP_SIZE);

                // Compute the UV base offset for the tile at (x, z)
                const tileIndex = self.tile_map[x][z];
                const uvXBase = @as(f32, @floatFromInt(tileIndex % TILE_MAP_SIZE)) * uvTileSize;
                const uvYBase = @as(f32, @floatFromInt(tileIndex / TILE_MAP_SIZE)) * uvTileSize;

                // THID METHOD GETS MAX 1800 MIN 1150 FPS
                // Fill texcoords array with adjusted UV coordinates
                mesh.texcoords[tcCounter] = uvXBase;
                mesh.texcoords[tcCounter + 1] = uvYBase;

                mesh.texcoords[tcCounter + 2] = uvXBase;
                mesh.texcoords[tcCounter + 3] = uvYBase + uvTileSize;

                mesh.texcoords[tcCounter + 4] = uvXBase + uvTileSize;
                mesh.texcoords[tcCounter + 5] = uvYBase;

                mesh.texcoords[tcCounter + 6] = mesh.texcoords[tcCounter + 4];
                mesh.texcoords[tcCounter + 7] = mesh.texcoords[tcCounter + 5];

                mesh.texcoords[tcCounter + 8] = mesh.texcoords[tcCounter + 2];
                mesh.texcoords[tcCounter + 9] = mesh.texcoords[tcCounter + 3];

                mesh.texcoords[tcCounter + 10] = uvXBase + uvTileSize;
                mesh.texcoords[tcCounter + 11] = uvYBase + uvTileSize;
                tcCounter += 12; // 6 texcoords, 12 floats
                
                // Fill normals array with data
                //--------------------------------------------------------------
                // var i: usize = 0;
                // while(i<18) : (i+=9) {
                //     vA.x = mesh.vertices[nCounter + i];
                //     vA.y = mesh.vertices[nCounter + i + 1];
                //     vA.z = mesh.vertices[nCounter + i + 2];

                //     vB.x = mesh.vertices[nCounter + i + 3];
                //     vB.y = mesh.vertices[nCounter + i + 4];
                //     vB.z = mesh.vertices[nCounter + i + 5];

                //     vC.x = mesh.vertices[nCounter + i + 6];
                //     vC.y = mesh.vertices[nCounter + i + 7];
                //     vC.z = mesh.vertices[nCounter + i + 8];

                //     vN = rl.Vector3Normalize(rl.Vector3CrossProduct(rl.Vector3Subtract(vB, vA), rl.Vector3Subtract(vC, vA)));

                //     mesh.normals[nCounter + i] = vN.x;
                //     mesh.normals[nCounter + i + 1] = vN.y;
                //     mesh.normals[nCounter + i + 2] = vN.z;

                //     mesh.normals[nCounter + i + 3] = vN.x;
                //     mesh.normals[nCounter + i + 4] = vN.y;
                //     mesh.normals[nCounter + i + 5] = vN.z;

                //     mesh.normals[nCounter + i + 6] = vN.x;
                //     mesh.normals[nCounter + i + 7] = vN.y;
                //     mesh.normals[nCounter + i + 8] = vN.z;
                // }
                // nCounter += 18;     // 6 vertex, 18 floats
            }
        }
        rl.UploadMesh(&mesh, false);
        self.model = rl.LoadModelFromMesh(mesh);

        // const shader = rl.LoadShader("resources/terrain.vs", "resources/terrain.fs");
        // self.model.materials[0].shader = shader;

        const texture = rl.LoadTexture("atlas_2x2.png");
        self.model.materials[0].maps[rl.MATERIAL_MAP_DIFFUSE].texture = texture;
    }

    pub fn renderMesh(self: *Chunk) void {
        if (self.model.meshCount > 0) {
            rl.DrawModel(self.model, self.wpos, 1.0, rl.WHITE);
        }
    }

pub fn renderCustomMesh(self: *Chunk) void {
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
    rl.glDrawArrays(rl.GL_TRIANGLES, 0, self.mesh.vertex_count);

    // Cleanup state
    if (texLoc != -1) {
        rl.rlDisableTexture();
    }
    
    rl.rlDisableVertexArray();
    rl.glBindBuffer(rl.GL_ARRAY_BUFFER, 0);
    
    rl.EndShaderMode();

    // Restore matrices
    rl.rlSetMatrixModelview(matView);
    rl.rlSetMatrixProjection(matProjection);
}
    pub fn deinit(self: *Chunk) void {
        _ = self;
        // rl.UnloadModel(self.model);
    }
};
