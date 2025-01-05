const std = @import("std");
const rl = @import("rl.zig");
// const chunk = @import("chunk.zig");
const ChunkManager = @import("chunk_manager.zig").ChunkManager;

const CHUNK_AMOUNT = 1;

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
    camera.position = rl.Vector3{ .x = -24.0, .y = 21.0, .z = -24.0 }; // Position the camera
    camera.target = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }; // Look at the origin
    camera.up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 }; // Set the up vector
    camera.fovy = 10.0; // Field of view
    camera.projection = rl.CAMERA_ORTHOGRAPHIC; // Set the camera type to orthographic

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var chunk_manager: ChunkManager = try ChunkManager.init(allocator);
    defer chunk_manager.deinit();

    var x: i32 = -CHUNK_AMOUNT;
    while(x < CHUNK_AMOUNT) : (x+=1) {
        var z: i32 = -CHUNK_AMOUNT;
        while(z < CHUNK_AMOUNT) : (z+=1) {
            // 255 because it's 255 degrees of freedom between 0 and 1
            // so 64 units up would be 255
            // and we can make a function for this, so it would be chunk_amount*255 + [0-255]
            try chunk_manager.createChunk(x, (255*0) + 0, z);
        }
    }
    chunk_manager.bindData();

    // const t = rl.LoadTexture("dirt.png");
    
    // rl.SetTargetFPS(144);
    while(!rl.WindowShouldClose()) {
        // UPDATE THINGS
        rl.UpdateCamera(&camera, rl.CAMERA_ORBITAL);
        rl.DisableCursor();

        // DRAW THINGS
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(.{.r = 0xA1, .g = 0xCD, .b = 0xF4, .a = 0xFF});
 
        rl.BeginMode3D(camera);
        // rl.DrawBillboard(camera, t, .{.x = 0, .y = 0, .z = 0}, 4.0, rl.WHITE);
        rl.DrawCubeV(.{.x = 0.5, .y = 0.5, .z = 0.5}, .{.x=1, .y=1, .z=1}, rl.WHITE);

        chunk_manager.render();

        drawAxisLines();
        rl.EndMode3D();
        rl.DrawFPS(10, 10);
    }
}
