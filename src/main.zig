const std = @import("std");
const rl = @import("rl.zig");
const chunk = @import("chunk.zig");

const CHUNK_AMOUNT = 3;

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
    // var c = chunk.Chunk.init(allocator, 0, 0);
    // defer c.deinit();
    // try c.generateMesh(rl.Vector3{.x = 128, .y = 255.0, .z = 128});

    var chunk_array: [CHUNK_AMOUNT*2*CHUNK_AMOUNT*2]chunk.Chunk = undefined;
    var chunk_index: usize = 0;
    var x: i32 = -CHUNK_AMOUNT;
    while(x < CHUNK_AMOUNT) : (x+=1) {
        var z: i32 = -CHUNK_AMOUNT;
        while(z < CHUNK_AMOUNT) : (z+=1) {
            var c = chunk.Chunk.init(allocator, x, z);
            // try c.generateMesh(rl.Vector3{.x = 16, .y = 10, .z = 16});
            // try c.generateMeshOptimized();
            // try c.generateMeshOptimizedCustom();
            try c.generateMeshOptimizedCustomIndices();
            // try c.generateMeshOptimizedCustomStrip();
            chunk_array[chunk_index] = c;
            chunk_index+=1;
        }
    }

    // var lastTime = rl.GetTime();
    while(!rl.WindowShouldClose()) {
        // const currentTime = rl.GetTime();
        // const deltaTime = currentTime - lastTime;
        // lastTime = currentTime;
        // UPDATE THINGS
        rl.UpdateCamera(&camera, rl.CAMERA_FIRST_PERSON);

        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BLACK);
 
        rl.BeginMode3D(camera);

        // c.renderMesh();
        for(0..CHUNK_AMOUNT*2*CHUNK_AMOUNT*2) |i| {
            // chunk_array[i].renderMesh();
            // chunk_array[i].renderCustomMesh();
            chunk_array[i].renderCustomMeshIndices();
            // chunk_array[i].renderCustomMeshStrip();
        }

        drawAxisLines();
        rl.EndMode3D();
        rl.DrawFPS(10, 10);
    }

    for(0..CHUNK_AMOUNT*2*CHUNK_AMOUNT*2) |i| {
        chunk_array[i].deinit();
    }
}
