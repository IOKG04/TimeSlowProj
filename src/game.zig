const std = @import("std");
const raylib = @import("raylib");
const options = @import("options");

const scene = @import("scene.zig");
const GameObject = @import("GameObject.zig");
const objects = @import("objects.zig");

const Allocator = std.mem.Allocator;

pub var state: State = .game;
pub var player: *objects.Player = undefined;
pub var camera: raylib.Camera2D = .{
    .offset = .{ .x = @abs(options.window_w) / 2, .y = @abs(options.window_h) / 2 },
    .target = .{ .x = 0.0, .y = 0.0 },
    .rotation = 0.0,
    .zoom = @as(f32, @floatFromInt(options.window_h)) / 8.0,
};

pub fn init(gpa: Allocator) !void {
    // init raylib
    raylib.initWindow(options.window_w, options.window_h, "TimeSlowProj");
    while (!raylib.isWindowReady()) {
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
    raylib.setTargetFPS(options.target_fps);

    // set/load/init initial game scene
    errdefer scene.deinit(gpa);
    {
        player = try .init(gpa);
        errdefer player.game_object.deinit(&player.game_object, gpa);
        try scene.addGameObject(gpa, &player.game_object);
    }
}

pub fn close(gpa: Allocator) void {
    scene.deinit(gpa);
    raylib.closeWindow();
}

pub fn run(gpa: Allocator) !void {
    while (!raylib.windowShouldClose()) {
        const dt = raylib.getFrameTime();
        try scene.update(gpa, dt, player.game_object.transform.position, -0.1);

        // zig fmt: off
        raylib.beginDrawing();
            raylib.clearBackground(.black);
            camera.begin();
                scene.draw();
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
