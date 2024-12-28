const std = @import("std");
const rl = @import("rl.zig");
const chunk = @import("chunk.zig");

pub const WorldManager = struct {
    loaded_chunks: std.AutoHashMap(rl.Vector2, *chunk.Chunk),
    active_chunks: std.ArrayList(*chunk.Chunk),
    allocator: std.mem.Allocator,
    chunk_load_radius: i32,

    pub fn init(allocator: std.mem.Allocator) WorldManager {
        return .{
            .loaded_chunks = std.AutoHashMap(rl.Vector2, *chunk.Chunk).init(allocator),
            .active_chunks = std.ArrayList(*chunk.Chunk).init(allocator),
            .allocator = allocator,
            .chunk_load_radius = 2,
        };
    }

    pub fn deinit(self: *WorldManager) void {
        var chunk_iter = self.loaded_chunks.valueIterator();
        while (chunk_iter.next()) |c| {
            chunk.*.deinit();
            self.allocator.destroy(c.*);
        }
        self.loaded_chunks.deinit();
        self.active_chunks.deinit();
    }

    pub fn updateActiveChunks(self: *WorldManager, player_pos: rl.Vector2) !void {
        const player_chunk_x = @divFloor(@as(i32, @intFromFloat(player_pos.x)), chunk.CHUNK_SIZE);
        const player_chunk_y = @divFloor(@as(i32, @intFromFloat(player_pos.y)), chunk.CHUNK_SIZE);

        // Clear previous active status
        for (self.active_chunks.items) |c| {
            c.is_active = false;
        }
        self.active_chunks.clearRetainingCapacity();

        // Load and activate chunks in radius around player
        var y = player_chunk_y - self.chunk_load_radius;
        while (y <= player_chunk_y + self.chunk_load_radius) : (y += 1) {
            var x = player_chunk_x - self.chunk_load_radius;
            while (x <= player_chunk_x + self.chunk_load_radius) : (x += 1) {
                const c = try self.getChunkAt(x * chunk.CHUNK_SIZE, y * chunk.CHUNK_SIZE);
                c.is_active = true;
                try self.active_chunks.append(c);
            }
        }

        // Unload distant chunks
        var chunk_iter = self.loaded_chunks.iterator();
        while (chunk_iter.next()) |entry| {
            const chunk_x = entry.key_ptr.*.x;
            const chunk_y = entry.key_ptr.*.y;
            
            const dx = @abs(chunk_x - player_chunk_x);
            const dy = @abs(chunk_y - player_chunk_y);
            
            if (dx > self.chunk_load_radius + 1 or dy > self.chunk_load_radius + 1) {
                const c = entry.value_ptr.*;
                c.deinit();
                self.allocator.destroy(chunk);
                _ = self.loaded_chunks.remove(entry.key_ptr.*);
            }
        }
    }
};