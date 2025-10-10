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

var primary_render_target: raylib.RenderTexture2D = undefined;
var gaussian_horizontal: raylib.Shader = undefined;
var gaussian_horizontal_target: raylib.RenderTexture2D = undefined;
var gaussian_vertical: raylib.Shader = undefined;

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

    primary_render_target = try raylib.loadRenderTexture(options.window_w, options.window_h);
    errdefer primary_render_target.unload();
    gaussian_horizontal = try raylib.loadShader(null, "resources/shaders/gaussian_horizontal.glsl");
    errdefer gaussian_horizontal.unload();
    gaussian_horizontal_target = try raylib.loadRenderTexture(options.window_w, options.window_h);
    errdefer gaussian_horizontal_target.unload();
    gaussian_vertical = try raylib.loadShader(null, "resources/shaders/gaussian_vertical.glsl");
    errdefer gaussian_vertical.unload();
}

pub fn close(gpa: Allocator) void {
    primary_render_target.unload();
    gaussian_horizontal.unload();
    gaussian_horizontal_target.unload();
    gaussian_vertical.unload();

    scene.deinit(gpa);
    raylib.closeWindow();
}

pub fn run(gpa: Allocator) !void {
    while (!raylib.windowShouldClose()) {
        const dt = raylib.getFrameTime();
        try scene.update(gpa, dt, player.game_object.transform.position, -0.1);

        // zig fmt: off
        primary_render_target.begin();
            raylib.clearBackground(.black);
            camera.begin();
                scene.draw();
            camera.end();
        primary_render_target.end();

        gaussian_horizontal_target.begin();
            gaussian_horizontal.activate();
                primary_render_target.texture.drawRec(.{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(primary_render_target.texture.width),
                    .height = @floatFromInt(-primary_render_target.texture.height),
                }, .{
                    .x = 0,
                    .y = 0,
                }, .white);
            gaussian_horizontal.deactivate();
        gaussian_horizontal_target.end();

        raylib.beginDrawing();
            gaussian_vertical.activate();
                gaussian_horizontal_target.texture.drawRec(.{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(gaussian_horizontal_target.texture.width),
                    .height = @floatFromInt(-gaussian_horizontal_target.texture.height),
                }, .{
                    .x = 0,
                    .y = 0,
                }, .white);
            gaussian_vertical.deactivate();
            raylib.drawFPS(0, 0);
        raylib.endDrawing();
        // zig fmt: on
    }
}

pub const State = enum {
    game,
    // main_menu, settings_menu, settings_menu_in_game, etc.
};
