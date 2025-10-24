//! Lazily loads textures as they're needed. Does not unload textures.
//!
//! This will always look at `options.texture_path/[name].png` to find the textures.

const std = @import("std");
const raylib = @import("raylib");
const options = @import("options");

const Allocator = std.mem.Allocator;
const Texture2D = raylib.Texture2D;

const log = @import("main.zig").log;

const TextureManager = @This();

arena: Allocator,
loaded: std.StringArrayHashMapUnmanaged(*const Texture2D) = .empty,

pub fn deinit(tm: *TextureManager, gpa: Allocator) void {
    for (tm.loaded.values()) |texture| {
        texture.unload();
    }
    tm.loaded.deinit(gpa);
    tm.loaded = .empty;
}

pub fn preload(tm: *TextureManager, gpa: Allocator, name: []const u8) LoadError!void {
    if (tm.loaded.contains(name)) return;
    try tm.preloadAssumeUnloaded(gpa, name);
}
pub fn preloadAssumeUnloaded(tm: *TextureManager, gpa: Allocator, name: []const u8) LoadError!void {
    _ = try tm.loadAssumeUnloaded(gpa, name);
}

pub fn load(tm: *TextureManager, gpa: Allocator, name: []const u8) LoadError!*const Texture2D {
    return tm.loaded.get(name) orelse try tm.loadAssumeUnloaded(gpa, name);
}
pub fn loadAssumeUnloaded(tm: *TextureManager, gpa: Allocator, name: []const u8) LoadError!*const Texture2D {
    const path = try std.fmt.allocPrintSentinel(gpa, "{s}/{s}.png", .{ options.texture_path, name }, 0);
    defer gpa.free(path);

    const texture = try tm.arena.create(Texture2D);
    texture.* = raylib.loadTexture(path) catch |err| switch (err) {
        error.LoadTexture => return error.LoadTexture,
        else => unreachable, // Despite the error set, no other error can be returned.
    };
    errdefer texture.*.unload();
    try tm.loaded.put(gpa, name, texture);

    log.debug("loaded texture '{s}'", .{name});

    return texture;
}

pub const LoadError = error {
    LoadTexture,
} || Allocator.Error;
