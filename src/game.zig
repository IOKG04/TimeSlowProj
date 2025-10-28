const std = @import("std");
const raylib = @import("raylib");
const options = @import("options");

const GameObject = @import("GameObject.zig");
const main = @import("main.zig");
const objects = @import("objects.zig");
const scene = @import("scene.zig");
const TextureManager = @import("TextureManager.zig");

const Allocator = std.mem.Allocator;

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
    errdefer raylib.closeWindow();
    raylib.setTargetFPS(options.target_fps);

    // init `texture_manager`
    texture_manager = .{ .arena = arena };
    errdefer texture_manager.deinit(gpa);

    // set/load/init initial game scene
    errdefer scene.deinit(gpa);
    player = try .init(gpa);

    // If an argument was provided,
    // interpret it as a level to load.
    if (main.args.len > 1) {
        const level_path = main.args[1];
        // TODO: Make the offset adjustable too.
        try scene.loadBackground(gpa, level_path, .{ .x = -2.0, .y = -2.0 });
    }
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

        switch (state) {
            .game => {
                try scene.update(gpa, dt, player.game_object.transform.position, -0.1);
            },
        }

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
    /// The primary game state, with the player,
    /// movement, guns, and all that stuff.
    game,
    // main_menu, settings_menu, settings_menu_in_game, etc.
};
