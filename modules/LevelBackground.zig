const std = @import("std");
const raylib = @import("raylib");
const Vec2 = @import("Vec2");
const Collision = @import("Collision");

const Allocator = std.mem.Allocator;
const Collider = Collision.Collider;

const LevelBackground = @This();

texture: *const raylib.Texture2D,
// Top-left-most (x-small, y-small) point
// where the level background is drawn.
origin: Vec2,
colliders: []Collider,

pub const File = struct {
    /// Relative path from file to texture.
    texture_path: []const u8,
    /// Positions should assume the origin is `0, 0`.
    colliders: []const Collider,
};

pub fn fromFile(gpa: Allocator, file: File, origin: Vec2) Allocator.Error!LevelBackground {
    _ = .{ gpa, file, origin };
    return error.OutOfMemory;
}
