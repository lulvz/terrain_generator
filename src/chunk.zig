const std = @import("std");
const rl = @import("rl.zig");

const sn = @import("simple-noises");

pub const MAX_HEIGHTMAP_VALUE = 255; // max u8

pub const CHUNK_SIZE: comptime_int = 64;
pub const CHUNK_SIZE_VERTICES: comptime_int = CHUNK_SIZE + 1;
pub const MAX_TRIANGLES = CHUNK_SIZE * CHUNK_SIZE * 2;
pub const MAX_VERTICES = MAX_TRIANGLES * 2;
pub const MAX_INDICES = MAX_TRIANGLES * 3;

const chunkVertexInformation = packed struct(u32) {
    height: u8,
    texture_id: u12, // total of 4096 textures in a 2048x2048 texture atlas
    normal_pitch: u6,
    normal_yaw: u6,
};

const TILE_MAP_SIZE: comptime_int = 64;

pub const Chunk = struct {
    // Raw world positions
    wx: i32,
    wz: i32,
    wpos: rl.Vector3,
    height_map: [CHUNK_SIZE_VERTICES*CHUNK_SIZE_VERTICES]u8,
    tile_map: [CHUNK_SIZE*CHUNK_SIZE]u12,

    pub fn init(wx: i32, wz: i32) Chunk {
        const height_map = std.mem.zeroes([CHUNK_SIZE_VERTICES*CHUNK_SIZE_VERTICES]u8);
        var tile_map = std.mem.zeroes([CHUNK_SIZE*CHUNK_SIZE]u12);

        const wpos = rl.Vector3{ 
            .x = @floatFromInt(wx * CHUNK_SIZE), 
            .y = 0, 
            .z = @floatFromInt(wz * CHUNK_SIZE) 
        };

        for(0..CHUNK_SIZE) |x| {
            for(0..CHUNK_SIZE) |z| {
                const tile_index = getTileMapIndex(x, z);
                tile_map[tile_index] = 1;
            }
        }

        return Chunk{
            .wx = wx,
            .wz = wz,
            .wpos = wpos,
            .height_map = height_map,
            .tile_map = tile_map,
        };
    }

    // Helper functions to convert 2D coordinates to 1D index
    fn getHeightMapIndex(x: usize, z: usize) usize {
        return x * CHUNK_SIZE_VERTICES + z;
    }

    fn getTileMapIndex(x: usize, z: usize) usize {
        return x * CHUNK_SIZE + z;
    }

    pub fn generateHeightMap(self: *Chunk, noise_generator: *sn.PerlinNoise2D(f64)) void {
        for(0..CHUNK_SIZE_VERTICES) |x| {
            for(0..CHUNK_SIZE_VERTICES) |z| {
                const idx = getHeightMapIndex(x, z);
                // Add the chunk's world position to the coordinates
                const world_x: f64 = @floatFromInt(self.wx * CHUNK_SIZE + @as(i32, @intCast(x)));
                const world_z: f64 = @floatFromInt(self.wz * CHUNK_SIZE + @as(i32, @intCast(z)));
                const height_fraction: f64 = (noise_generator.generate(world_x, world_z) + 1.0) / 2.0;
                self.height_map[idx] = @intFromFloat(height_fraction * 255.0);
            }
        }
    }

    // TODO MAKE THIS GENERATE THE MESH USING A PORTION OF A PERLIN NOISE MAP, ACCORDING TO ITS WORLD POSITION
    pub fn generateMesh(self: *Chunk, vertex_info: []u32, indices: []u32) !void {
        var vCounter: usize = 0;
        var iCounter: usize = 0;

        var x: usize = 0;
        while (x < CHUNK_SIZE_VERTICES - 1) : (x += 1) {
            var z: usize = 0;
            while (z < CHUNK_SIZE_VERTICES - 1) : (z += 1) {
                // Pack vertex information
                var info = chunkVertexInformation{
                    .height = self.height_map[getHeightMapIndex(x, z)],
                    .texture_id = self.tile_map[getTileMapIndex(x, z)],
                    .normal_pitch = 32, // Default to straight up
                    .normal_yaw = 0,
                };
                vertex_info[vCounter] = @bitCast(info);

                info.height = self.height_map[getHeightMapIndex(x, z + 1)];
                vertex_info[vCounter + 1] = @bitCast(info);

                info.height = self.height_map[getHeightMapIndex(x + 1, z)];
                vertex_info[vCounter + 2] = @bitCast(info);

                info.height = self.height_map[getHeightMapIndex(x + 1, z + 1)];
                vertex_info[vCounter + 3] = @bitCast(info);

                // TODO possible optimization: since the indices are always the same
                // maybe store them at comptime and don't compute them everytime
                // First triangle (top-left, bottom-left, top-right)
                indices[iCounter] = @intCast(vCounter);
                indices[iCounter + 1] = @intCast(vCounter + 1);
                indices[iCounter + 2] = @intCast(vCounter + 2);

                // Second triangle (top-right, bottom-left, bottom-right)
                indices[iCounter + 3] = @intCast(vCounter + 2);
                indices[iCounter + 4] = @intCast(vCounter + 1);
                indices[iCounter + 5] = @intCast(vCounter + 3);

                vCounter += 4;
                iCounter += 6;
            }
        }
    }

    pub fn saveChunk(self: *Chunk, file_name: []const u8) !void {
        const file = try std.fs.cwd().createFile(
            file_name,
            .{ .read = true, .truncate = true }
        );
        defer file.close();

        var buffered_writer = std.io.bufferedWriter(file.writer());
        var writer = buffered_writer.writer();

        try writer.writeAll(&self.height_map);
        try writer.writeAll(std.mem.sliceAsBytes(&self.tile_map));

        try buffered_writer.flush();
    }

    pub fn loadChunk(self: *Chunk, file_name: []const u8) !bool {
        // we have to load the file into a slice of u8 first, then we have to
        // cast that slice into the slice of u12
        // Try to open the file
        const file = std.fs.cwd().openFile(file_name, .{}) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        };
        defer file.close();

        var buffered_reader = std.io.bufferedReader(file.reader());
        var reader = buffered_reader.reader();

        // Read height map and tile map data
        _ = try reader.readAll(&self.height_map);
        // _ = try reader.readAll(&self.tile_map);
        return true;
    }

    pub fn deinit(self: *Chunk) void {
        _ = self;
    }
};
