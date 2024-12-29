const std = @import("std");
const rl = @import ("rl.zig");

const MAX_HEIGHTMAP_VALUE = 255.0;

// chunk width in terms of quads
const CHUNK_SIZE: comptime_int = 128;
const CHUNK_SIZE_VERTICES: comptime_int = CHUNK_SIZE+1;
const MAX_TRIANGLES = CHUNK_SIZE*CHUNK_SIZE*2;
const MAX_INDICES = (CHUNK_SIZE_VERTICES - 1) * (CHUNK_SIZE_VERTICES - 1) * 6;

pub const Chunk = struct {
    allocator: std.mem.Allocator,
    wx: i32,
    wz: i32,
    wpos: rl.Vector3,
    height_map: [CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]f32, // TODO make this load from this file: chunk_%d_%d.bin
    model: rl.Model,

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
            .model = undefined,
        };

        // Example height map with a gradient
        for (0..CHUNK_SIZE_VERTICES) |x| {
            for (0..CHUNK_SIZE_VERTICES) |z| {
                chunk.height_map[x][z] = 10*@as(f32, @floatFromInt(x + z)) /  @as(f32, @floatFromInt(CHUNK_SIZE));
            }
        }

        return chunk;
    }
    
    pub fn generateMesh(self: *Chunk, size: rl.Vector3) !void {
        var mesh: rl.Mesh = .{};

        mesh.triangleCount = MAX_TRIANGLES;
        mesh.vertexCount = MAX_TRIANGLES*3;

        // Allocate memory for vertices (3 floats per vertex: x,y,z)
        mesh.vertices = (try self.allocator.alloc(f32, @intCast(mesh.vertexCount*3))).ptr;
        // Allocate memory for normals (3 floats per normal: x,y,z)
        mesh.normals = (try self.allocator.alloc(f32, @intCast(mesh.vertexCount*3))).ptr;
        // Allocate memory for texture coordinates (2 floats per vertex: u,v)
        mesh.texcoords = (try self.allocator.alloc(f32, @intCast(mesh.vertexCount*2))).ptr;
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
        rl.UploadMesh(&mesh, false);

        var model: rl.Model = .{};

        model.transform = rl.MatrixIdentity();
        model.meshCount = 1;
        model.meshes = (try self.allocator.alloc(rl.Mesh, 1)).ptr;
        model.meshes[0] = mesh;

        model.materialCount = 1;
        model.materials = (try self.allocator.alloc(rl.Material, 1)).ptr;
        model.materials[0] = rl.LoadMaterialDefault();

        model.meshMaterial = (try self.allocator.alloc(i32, 1)).ptr;
        model.meshMaterial[0] = 0;

        self.model = model;
    }

    pub fn renderMesh(self: *Chunk) void {
        if (self.model.meshCount > 0) {
            rl.DrawModel(self.model, self.wpos, 1.0, rl.PURPLE);
        }
    }

    pub fn deinit(self: *Chunk) void {
        for(0..@intCast(self.model.meshCount)) |i| {
            self.allocator.free(self.model.meshes[i].vertices[0..@intCast(self.model.meshes[i].vertexCount*3)]);
            self.allocator.free(self.model.meshes[i].normals[0..@intCast(self.model.meshes[i].vertexCount*3)]);
            self.allocator.free(self.model.meshes[i].texcoords[0..@intCast(self.model.meshes[i].vertexCount*2)]);
        }
        self.allocator.free(self.model.materials[0..@intCast(self.model.materialCount)]);
        self.allocator.free(self.model.meshMaterial[0..@intCast(self.model.meshCount)]);
        self.allocator.free(self.model.meshes[0..@intCast(self.model.meshCount)]);
    }
};
