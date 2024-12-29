const std = @import("std");
const rl = @import("rl.zig");

const chunk = @import("chunk.zig");

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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var c = chunk.Chunk.init(allocator, 0, 0);
    defer c.deinit();
    rl.InitWindow(800, 600, "raylib-zig [core] example - sprite sheet rendering");
    defer rl.CloseWindow();

    var camera: rl.Camera3D = undefined;
    camera.position = rl.Vector3{ .x=-10.0, .y=200.0, .z=-10.0 }; // Camera position
    camera.target = rl.Vector3{ .x=0.0, .y=0.0, .z=0.0 };      // Camera looking at point
    camera.up = rl.Vector3{ .x=0.0, .y=1.0, .z=0.0 };          // Camera up vector (rotation towards target)
    camera.fovy = 45.0;                                // Camera field-of-view Y
    camera.projection = rl.CAMERA_PERSPECTIVE;             // Camera projection type
    
    try c.generateMesh(rl.Vector3{.x = 16, .y = 255.0, .z = 16});
    // c.printVertices();
    
    while(!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.BeginMode3D(camera);
        defer rl.EndMode3D();

        c.renderMesh();
        drawAxisLines();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
