const std = @import("std");
const rl = @import ("rl.zig");

const MAX_HEIGHTMAP_VALUE = 255.0;

// chunk width in terms of quads
const CHUNK_SIZE: comptime_int = 16;
const CHUNK_SIZE_VERTICES: comptime_int = CHUNK_SIZE+1;
const MAX_VERTICES = CHUNK_SIZE_VERTICES * CHUNK_SIZE_VERTICES;
const MAX_TRIANGLES = CHUNK_SIZE*CHUNK_SIZE*2;
const MAX_INDICES = (CHUNK_SIZE_VERTICES - 1) * (CHUNK_SIZE_VERTICES - 1) * 6;

pub const Chunk = struct {
    pub fn setHeightMap(self: *Chunk, height_map: [CHUNK_SIZE][CHUNK_SIZE]f32) void {
        @memcpy(self.height_map, height_map); 
    }

    allocator: std.mem.Allocator,
    wx: i32,
    wz: i32,
    height_map: [CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]f32, // TODO make this load from this file: chunk_%d_%d.bin
    vertices: [CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]rl.Vector3,
    indices: [MAX_INDICES]u32,

    pub fn init(allocator: std.mem.Allocator, wx: i32, wz: i32) Chunk {
        var chunk = Chunk {
            .allocator = allocator,
            .wx = wx,
            .wz = wz,
            .height_map = std.mem.zeroes([CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]f32),
            .vertices = undefined,
            .indices = undefined,
        };

        // Example height map with a gradient
        for (0..CHUNK_SIZE_VERTICES) |x| {
            for (0..CHUNK_SIZE_VERTICES) |z| {
                chunk.height_map[x][z] = 3*@as(f32, @floatFromInt(x + z)) /  @as(f32, @floatFromInt(CHUNK_SIZE));
            }
        }

        return chunk;
    }
    
    pub fn generateQuads(self: *Chunk) void {
        var vertex_index: usize = 0;
        var index_count: usize = 0;

        // Populate vertices
        for (0..CHUNK_SIZE_VERTICES) |x| {
            for (0..CHUNK_SIZE_VERTICES) |z| {
                self.vertices[x][z] = rl.Vector3{
                    .x = @floatFromInt(x),
                    .y = self.height_map[x][z],
                    .z = @floatFromInt(z),
                };
                vertex_index += 1;
            }
        }

        // Populate indices for quads
        for (0..CHUNK_SIZE_VERTICES - 1) |x| {
            for (0..CHUNK_SIZE_VERTICES - 1) |z| {
                const topLeft: u32 = @intCast(x * CHUNK_SIZE_VERTICES + z);
                const topRight: u32 = @intCast((x + 1) * CHUNK_SIZE_VERTICES + z);
                const bottomLeft: u32 = @intCast(x * CHUNK_SIZE_VERTICES + (z + 1));
                const bottomRight: u32 = @intCast((x + 1) * CHUNK_SIZE_VERTICES + (z + 1));

                // First triangle
                self.indices[index_count] = topLeft;
                self.indices[index_count + 1] = bottomLeft;
                self.indices[index_count + 2] = topRight;

                // Second triangle
                self.indices[index_count + 3] = topRight;
                self.indices[index_count + 4] = bottomLeft;
                self.indices[index_count + 5] = bottomRight;

                index_count += 6;
            }
        }
    }

    pub fn generateMesh(self: *Chunk, size: rl.Vector3) !rl.Mesh {
        var mesh: rl.Mesh = undefined;

        mesh.triangleCount = MAX_TRIANGLES;
        mesh.vertexCount = MAX_VERTICES;

        // Allocate memory for vertices (3 floats per vertex: x,y,z)
        mesh.vertices = (try self.allocator.alloc(f32, MAX_VERTICES * 3)).ptr;
        // Allocate memory for normals (3 floats per normal: x,y,z)
        mesh.normals = (try self.allocator.alloc(f32, MAX_VERTICES * 3)).ptr;
        // Allocate memory for texture coordinates (2 floats per vertex: u,v)
        mesh.texcoords = (try self.allocator.alloc(f32, MAX_VERTICES * 2)).ptr;
        mesh.colors = null;

        var vCounter: usize = 0;
        var tcCounter: usize = 0;
        var nCounter: usize = 0;

        var vA: rl.Vector3 = .{.x=0,.y=0,.z=0};
        var vB: rl.Vector3 = .{.x=0,.y=0,.z=0};
        var vC: rl.Vector3 = .{.x=0,.y=0,.z=0};
        var vN: rl.Vector3 = .{.x=0,.y=0,.z=0};

        const scaleFactor: rl.Vector3 = .{ .x = size.x/CHUNK_SIZE, .y = size.y/MAX_HEIGHTMAP_VALUE, .z = size.z/CHUNK_SIZE };

        var x: usize = 0;
        var z: usize = 0;
        while(x < CHUNK_SIZE_VERTICES-1) : (x+=1) {
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
                //--------------------------------------------------------------
                mesh.texcoords[tcCounter] = @as(f32, @floatFromInt(x))/(CHUNK_SIZE);
                mesh.texcoords[tcCounter + 1] = @as(f32, @floatFromInt(z))/(CHUNK_SIZE);

                mesh.texcoords[tcCounter + 2] = @as(f32, @floatFromInt(x))/(CHUNK_SIZE);
                mesh.texcoords[tcCounter + 3] = @as(f32, @floatFromInt(z + 1))/(CHUNK_SIZE);

                mesh.texcoords[tcCounter + 4] = @as(f32, @floatFromInt(x + 1))/(CHUNK_SIZE);
                mesh.texcoords[tcCounter + 5] = @as(f32, @floatFromInt(z))/(CHUNK_SIZE);

                mesh.texcoords[tcCounter + 6] = mesh.texcoords[tcCounter + 4];
                mesh.texcoords[tcCounter + 7] = mesh.texcoords[tcCounter + 5];

                mesh.texcoords[tcCounter + 8] = mesh.texcoords[tcCounter + 2];
                mesh.texcoords[tcCounter + 9] = mesh.texcoords[tcCounter + 3];

                mesh.texcoords[tcCounter + 10] = @as(f32, @floatFromInt(x + 1))/(CHUNK_SIZE);
                mesh.texcoords[tcCounter + 11] = @as(f32, @floatFromInt(z + 1))/(CHUNK_SIZE);
                tcCounter += 12;    // 6 texcoords, 12 floats

                // Fill normals array with data
                //--------------------------------------------------------------
                var i: usize = 0;
                while(i<18) : (i+=9) {
                    vA.x = mesh.vertices[nCounter + i];
                    vA.y = mesh.vertices[nCounter + i + 1];
                    vA.z = mesh.vertices[nCounter + i + 2];

                    vB.x = mesh.vertices[nCounter + i + 3];
                    vB.y = mesh.vertices[nCounter + i + 4];
                    vB.z = mesh.vertices[nCounter + i + 5];

                    vC.x = mesh.vertices[nCounter + i + 6];
                    vC.y = mesh.vertices[nCounter + i + 7];
                    vC.z = mesh.vertices[nCounter + i + 8];

                    vN = rl.Vector3Normalize(rl.Vector3CrossProduct(rl.Vector3Subtract(vB, vA), rl.Vector3Subtract(vC, vA)));

                    mesh.normals[nCounter + i] = vN.x;
                    mesh.normals[nCounter + i + 1] = vN.y;
                    mesh.normals[nCounter + i + 2] = vN.z;

                    mesh.normals[nCounter + i + 3] = vN.x;
                    mesh.normals[nCounter + i + 4] = vN.y;
                    mesh.normals[nCounter + i + 5] = vN.z;

                    mesh.normals[nCounter + i + 6] = vN.x;
                    mesh.normals[nCounter + i + 7] = vN.y;
                    mesh.normals[nCounter + i + 8] = vN.z;
                }
                nCounter += 18;     // 6 vertex, 18 floats
            }
        }
        return mesh;
    }

    pub fn renderCubes(self: *Chunk) void {
        for(0..CHUNK_SIZE) |x| {
            for(0..CHUNK_SIZE) |z| {
                rl.DrawCubeWiresV(
                    .{.x=0.5 + self.wx + @as(f32, @floatFromInt(x)),.y=self.height_map[x][z],.z=0.5 + self.wz + @as(f32, @floatFromInt(z))},
                    .{.x=1, .y=1, .z=1},
                    rl.RED
                );
            }
        }
    }

    pub fn renderQuads(self: *Chunk) void {
    var i: usize = 0;
    while(i < self.indices.len - 2) : (i += 3) {
        // Convert 1D indices to 2D coordinates
        const x1 = self.indices[i] / CHUNK_SIZE_VERTICES;
        const z1 = self.indices[i] % CHUNK_SIZE_VERTICES;
        
        const x2 = self.indices[i + 1] / CHUNK_SIZE_VERTICES;
        const z2 = self.indices[i + 1] % CHUNK_SIZE_VERTICES;
        
        const x3 = self.indices[i + 2] / CHUNK_SIZE_VERTICES;
        const z3 = self.indices[i + 2] % CHUNK_SIZE_VERTICES;

        const v1 = self.vertices[x1][z1];
        const v2 = self.vertices[x2][z2];
        const v3 = self.vertices[x3][z3];

        rl.DrawTriangle3D(v1, v2, v3, rl.Color{
            .r = @intCast(i * 255 / self.indices.len), 
            .g = 0, 
            .b = 0, 
            .a = 255
        });
    }
}

    pub fn renderMesh(self: *Chunk) void {
        if (self.model.meshCount > 0) {
            const position = rl.Vector3{
                .x = @floatFromInt(self.wx * CHUNK_SIZE),
                .y = 0,
                .z = @floatFromInt(self.wz * CHUNK_SIZE),
            };
            rl.DrawModel(self.model, position, 1.0, rl.GREEN);
        }
    }

    pub fn deinit(self: *Chunk) void {
        _=self;
        // TODO DEINIT THE MESH
        // we have to convert the c pointers back to slices to free them
        // self.allocator.free(mesh.vertices[0..(MAX_VERTICES * 3)]);
        return;
    }
};
