const std = @import("std");

const game = @import("game.zig");
const GameObject = @import("GameObject.zig");
const Vec2 = @import("Vec2.zig");

const Allocator = std.mem.Allocator;
const Collider = GameObject.Collider;
const DrawObject = GameObject.DrawObject;

const Tilemap = @This();

/// Coordinate of the top left
/// corner of the top left tile.
origin: Vec2,
/// Width and height of the map
/// in tiles.
size: Size,
/// Size of every tile in units.
tile_scale: Vec2,

/// Map data of which tile is where.
/// `null` implies there is no tile there.
data: []?*const Tile,
/// Actual tiles.
tiles: []Tile,

pub const Tile = struct {
    draw: DrawObject = .{ .rectangle = .white },
    /// A tile might often need two colliders to work correctly.
    /// Example: The '+' tile.
    colliders: [2]Collider = .{
        .{ .rectangle = .{} },
        .none,
    },
};
pub const Size = struct {
    width: u32,
    height: u32,
    pub const zero: Size = .{
        .width = 0,
        .height = 0,
    };
};

pub const empty: Tilemap = .{
    .origin = .zero,
    .size = .zero,
    .tile_scale = .one,
    .data = &.{},
    .tiles = &.{},
};

/// Creates a tilemap from a string.
///
/// A ' ' indicated empty space, a '#' is
/// filled. Any unfilled characters in the
/// `size` sized grid are interpreted as
/// empty space.
///
/// If a line exceeds `size.width` characters,
/// behaviour is undefined.
pub fn fromString(gpa: Allocator, origin: Vec2, size: Size, tile_scale: Vec2, data: []const u8) FromStringError!Tilemap {
    var outp: Tilemap = .{
        .origin = origin,
        .size = size,
        .tile_scale = tile_scale,
        .data = undefined,
        .tiles = undefined,
    };
    outp.data = try gpa.alloc(?*const Tile, size.width * size.height);
    errdefer gpa.free(outp.data);
    outp.tiles = try gpa.alloc(Tile, 1);
    errdefer gpa.free(outp.tiles);

    outp.tiles[0] = .{};

    var idx_outp: usize = 0;
    var idx_inp: usize = 0;
    while (idx_outp < size.width * size.height) {
        switch (data[idx_inp]) {
            ' ' => {
                outp.data[idx_outp] = null;
                idx_outp += 1;
                idx_inp += 1;
            },
            '#' => {
                outp.data[idx_outp] = &outp.tiles[0];
                idx_outp += 1;
                idx_inp += 1;
            },
            '\n' => {
                const remaining = size.width - (idx_outp % size.width);
                if (remaining == size.width and !(idx_inp == 0 or data[idx_inp - 1] == '\n')) {
                    idx_inp += 1;
                    continue;
                }
                for (0..remaining) |_| {
                    outp.data[idx_outp] = &outp.tiles[0];
                    idx_outp += 1;
                }
                idx_inp += 1;
            },
            else => return error.InvalidCharacter,
        }
    }

    return outp;
}

pub fn deinit(tm: Tilemap, gpa: Allocator) void {
    gpa.free(tm.data);
    gpa.free(tm.tiles);
}

pub const FromStringError = error {
    InvalidCharacter,
} || Allocator.Error;
