const std = @import("std");
const rl = @import ("rl.zig");

pub const MAX_HEIGHTMAP_VALUE = 255;

// chunk width in terms of quads
pub const CHUNK_SIZE: comptime_int = 64;
pub const CHUNK_SIZE_VERTICES: comptime_int = CHUNK_SIZE+1;
pub const MAX_TRIANGLES = CHUNK_SIZE*CHUNK_SIZE*2;
pub const MAX_VERTICES = MAX_TRIANGLES*2;
pub const MAX_INDICES = MAX_TRIANGLES*3;

const ChunkMesh = struct {
    vao: c_uint,
    vbo: [2]c_uint,
    ebo: c_uint,
    vertex_count: i32,
};

const chunkVertexInformation = packed struct(u32) {
    height: u8,
    texture_id: u12, // total of 4096 textures in a 2048x2048 texture atlas
    normal_pitch: u6,
    normal_yaw: u6,
};

const TILE_MAP_SIZE: comptime_int = 64;

pub const Chunk = struct {
    wpos: rl.Vector3,
    height_map: [CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]u8,
    tile_map: [CHUNK_SIZE][CHUNK_SIZE]u12,

    pub fn init(wpos: rl.Vector3) Chunk {
        var chunk = Chunk{
            .wpos = wpos,
            .height_map = std.mem.zeroes([CHUNK_SIZE_VERTICES][CHUNK_SIZE_VERTICES]u8),
            .tile_map = std.mem.zeroes([CHUNK_SIZE][CHUNK_SIZE]u12),
        };

        // Initialize height_map and tile_map
        for (0..CHUNK_SIZE_VERTICES-1) |x| {
            for (0..CHUNK_SIZE_VERTICES-1) |z| {
                // chunk.height_map[x][z] = @intCast(x + z); // Example height map data
                // chunk.tile_map[x][z] = @intCast((x+z)%4);
                chunk.tile_map[x][z] = 2;
            }
        }
        return chunk;
    }

    // We take in the arrays to populate from the information about the chunk contained in this struct
    pub fn generateMesh(self: *Chunk, vertex_info: []u32, indices: []u32) !void {
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

    }

    // pub fn render(self: *Chunk, shader: rl.Shader) void {
    //     // Set up wpos
    //     const wposLoc = rl.GetShaderLocation(shader, "wpos");
    //     rl.SetShaderValueV(shader, wposLoc, &self.wpos, rl.SHADER_UNIFORM_VEC3, 1);

    //     // If VAO not available, set up vertex attributes and indices manually
    //     if (!rl.rlEnableVertexArray(self.mesh.vao)) {
    //         // Bind and set up heights (vertex positions)
    //         rl.glBindBuffer(rl.GL_ARRAY_BUFFER, self.mesh.vbo[0]);
    //         const vertexLoc = rl.GetShaderLocation(shader, "vertexInfo");
    //         if (vertexLoc != -1) {
    //             rl.glVertexAttribPointer(
    //                 @intCast(vertexLoc), 
    //                 1, 
    //                 rl.GL_INT, 
    //                 rl.GL_FALSE, 
    //                 0, 
    //                 null
    //             );
    //             rl.glEnableVertexAttribArray(@intCast(vertexLoc));
    //         }

    //         // Bind the element buffer object
    //         rl.glBindBuffer(rl.GL_ELEMENT_ARRAY_BUFFER, self.mesh.ebo);
    //     }

    //     rl.glDrawElements(rl.GL_TRIANGLES, @intCast(self.mesh.vertex_count), rl.GL_UNSIGNED_INT, null);
    // }

    pub fn deinit(self: *Chunk) void {
        _ = self;
    }
};
