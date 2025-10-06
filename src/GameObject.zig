const std = @import("std");
const raylib = @import("raylib");

const Vec2 = @import("Vec2.zig");

const Allocator = std.mem.Allocator;

const GameObject = @This();

update: *const fn (go: *GameObject, gpa: Allocator, dt: f32) UpdateError!void,
deinit: *const fn (go: *GameObject, gpa: Allocator) void,

paused: bool = false,

transform: Transform = .{},
draw: DrawObject = .none,
draw_order: DrawOrder = .default,

pub const Transform = struct {
    position: Vec2 = .zero,
    rotation: f32 = 0.0,
    scale: Vec2 = .one,
};
pub const DrawObject = union (enum) {
    none: void,
    texture: *const raylib.Texture2D,
    circle: raylib.Color,
};
pub const DrawOrder = enum {
    invisible,
    background,
    default,
    foreground,
};
pub const UpdateError = error {
    GenericError,
} || Allocator.Error;
