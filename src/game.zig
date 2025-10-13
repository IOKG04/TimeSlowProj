const std = @import("std");
const raylib = @import("raylib");
const options = @import("options");

const GameObject = @import("GameObject.zig");
const objects = @import("objects.zig");
const scene = @import("scene.zig");
const TextureManager = @import("TextureManager.zig");

const Allocator = std.mem.Allocator;

// Update this alongside ../resources/textures/README.
pub const pixels_per_unit = 16;
pub const units_per_pixel = 1.0 / @as(comptime_float, pixels_per_unit);

pub var state: State = .game;
pub var player: *objects.Player = undefined;
pub var camera: raylib.Camera2D = .{
    .offset = .{ .x = @abs(options.window_w) / 2, .y = @abs(options.window_h) / 2 },
    .target = .{ .x = 0.0, .y = 0.0 },
    .rotation = 0.0,
    .zoom = @as(f32, @floatFromInt(options.window_h)) / 8.0,
};
pub var texture_manager: TextureManager = undefined;

pub fn init(gpa: Allocator, arena: Allocator) !void {
    // init raylib
    raylib.initWindow(options.window_w, options.window_h, "TimeSlowProj");
    while (!raylib.isWindowReady()) {
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
    raylib.setTargetFPS(options.target_fps);

    // init `texture_manager`
    texture_manager = .{ .arena = arena };
    errdefer texture_manager.deinit(gpa);

    // set/load/init initial game scene
    errdefer scene.deinit(gpa);
    player = try .init(gpa);
}

pub fn close(gpa: Allocator, arena: Allocator) void {
    _ = arena;

    texture_manager.deinit(gpa);
    scene.deinit(gpa);
    raylib.closeWindow();
}

pub fn run(gpa: Allocator, arena: Allocator) !void {
    _ = arena;

    while (!raylib.windowShouldClose()) {
        const dt = raylib.getFrameTime();
        try scene.update(gpa, dt, player.game_object.transform.position, -0.1);

        // zig fmt: off
        raylib.beginDrawing();
            raylib.clearBackground(.black);
            camera.begin();
                scene.draw();
                if (options.draw_colliders) scene.drawColliders();
            camera.end();
            raylib.drawFPS(0, 0);
        raylib.endDrawing();
        // zig fmt: on
    }
}

pub const State = enum {
    game,
    // main_menu, settings_menu, settings_menu_in_game, etc.
};
