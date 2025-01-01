const std = @import("std");
const rl = @import("rl.zig");

const Chunk = @import("chunk.zig").Chunk;

pub const ChunkManager = struct {
    allocator: std.mem.Allocator,
    shader: rl.Shader,
    texture: rl.Texture,
    chunks: std.ArrayList(*Chunk),

    pub fn init(allocator: std.mem.Allocator) !ChunkManager {
        const c = ChunkManager{
            .allocator = allocator,
            .shader = rl.LoadShader("resources/terrain_indices.vs", "resources/terrain_indices.fs"),
            .texture = rl.LoadTexture("atlas_2x2.png"),
            .chunks = std.ArrayList(*Chunk).init(allocator),
        };

        return c;
    }

    pub fn createChunk(self: *ChunkManager, wx: i32, wz: i32) !void {
        const chunk = try self.allocator.create(Chunk);
        chunk.* = Chunk.init(self.allocator, wx, wz);
        _ = try chunk.generateMeshOptimizedCustomIndices();
        try self.chunks.append(chunk);
    }

    pub fn render(self: *ChunkManager) void {
        for (self.chunks.items) |chunk| {
            chunk.render(self.shader, self.texture);
        }
    }

    pub fn deinit(self: *ChunkManager) void {
        for (self.chunks.items) |chunk| {
            chunk.deinit();
            self.allocator.destroy(chunk);
        }
        self.chunks.deinit();
        rl.UnloadShader(self.shader);
        rl.UnloadTexture(self.texture);
    }
};
