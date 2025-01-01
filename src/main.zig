const std = @import("std");
const rl = @import("rl.zig");
// const chunk = @import("chunk.zig");
const ChunkManager = @import("chunk_manager.zig").ChunkManager;

const CHUNK_AMOUNT = 20;

fn drawAxisLines() void {
    const origin = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    const x_end = rl.Vector3{ .x = 10.0, .y = 0.0, .z = 0.0 };
    const y_end = rl.Vector3{ .x = 0.0, .y = 10.0, .z = 0.0 };
    const z_end = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 10.0 };

    rl.DrawLine3D(origin, x_end, rl.RED);    // X-axis in red
    rl.DrawLine3D(origin, y_end, rl.GREEN);  // Y-axis in green
    rl.DrawLine3D(origin, z_end, rl.BLUE);   // Z-axis in blue
}

pub fn main() !void {
    rl.InitWindow(1600, 900, "raylib-zig [core] example - sprite sheet rendering");
    defer rl.CloseWindow();

    var camera: rl.Camera3D = undefined;
    camera.position = rl.Vector3{ .x=-10.0, .y=2.0, .z=-10.0 }; // Camera position
    camera.target = rl.Vector3{ .x=0, .y=10.0, .z=3 };      // Camera looking at point
    camera.up = rl.Vector3{ .x=0.0, .y=1.0, .z=0.0 };          // Camera up vector (rotation towards target)
    camera.fovy = 75.0;                                // Camera field-of-view Y
    camera.projection = rl.CAMERA_PERSPECTIVE;             // Camera projection type

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var chunk_manager: ChunkManager = try ChunkManager.init(allocator);
    defer chunk_manager.deinit();

    var x: i32 = -CHUNK_AMOUNT;
    while(x < CHUNK_AMOUNT) : (x+=1) {
        var z: i32 = -CHUNK_AMOUNT;
        while(z < CHUNK_AMOUNT) : (z+=1) {
            try chunk_manager.createChunk(x, z);
        }
    }
    
    while(!rl.WindowShouldClose()) {
        // UPDATE THINGS
        rl.UpdateCamera(&camera, rl.CAMERA_FIRST_PERSON);

        // DRAW THINGS
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BLACK);
 
        rl.BeginMode3D(camera);

        chunk_manager.render();

        drawAxisLines();
        rl.EndMode3D();
        rl.DrawFPS(10, 10);
    }
}
