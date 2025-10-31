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

    const player = try objects.Player.init(gpa);
    scene.center_of_gravity = &player.game_object.transform.position;

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
                try scene.update(gpa, dt);
            },
        }

        {
            raylib.beginDrawing();
            defer raylib.endDrawing();

            raylib.clearBackground(.black);
            scene.draw();
            if (options.draw_colliders) scene.drawColliders();
            raylib.drawFPS(0, 0);
        }
    }
}

pub const State = enum {
    /// The primary game state, with the player,
    /// movement, guns, and all that stuff.
    game,
    // main_menu, settings_menu, settings_menu_in_game, etc.
};
