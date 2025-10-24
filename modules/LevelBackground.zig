const std = @import("std");
const raylib = @import("raylib");
const Vec2 = @import("Vec2");
const Collision = @import("Collision");

const log = std.log.scoped(.level_background);

const Allocator = std.mem.Allocator;
const Collider = Collision.Collider;

const LevelBackground = @This();

// Top-left-most (x-small, y-small) point
// where the level background is drawn.
origin: Vec2,
texture: raylib.Texture2D,
colliders: []Collider,

pub const File = struct {
    /// Relative path from file to texture.
    texture_path: []const u8,
    /// Positions should assume the origin is `0, 0`.
    colliders: []const Collider,
};

/// Asserts none of the colliders are `none`.
pub fn load(gpa: Allocator, path: []const u8, origin: Vec2) !LevelBackground {
    const file_contents: [:0]const u8 = blk: {
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();

        var file_reader_buffer: [1024]u8 = undefined;
        var file_reader_outer = file.reader(&file_reader_buffer);
        const file_reader = &file_reader_outer.interface;

        if (file_reader_outer.size) |size| { // If we know the size, allocate the right amount first try.
            const contents: [:0]u8 = try gpa.allocSentinel(u8, @intCast(size), 0);
            errdefer gpa.free(contents);
            file_reader.readSliceAll(contents) catch |err| switch (err) {
                error.EndOfStream => unreachable,
                else => return err,
            };
            break :blk contents;
        } else { // If not, two allocations must happen sadly 3:
            const contents_no_sentinel = try file_reader.allocRemaining(gpa, .unlimited);
            defer gpa.free(contents_no_sentinel);
            const contents = try gpa.dupeZ(u8, contents_no_sentinel);
            errdefer gpa.free(contents);
            break :blk contents;
        }
    };
    defer gpa.free(file_contents);

    const file = try std.zon.parse.fromSlice(File, gpa, file_contents, null, .{});
    defer std.zon.parse.free(gpa, file);

    const colliders = try gpa.dupe(Collider, file.colliders);
    errdefer gpa.free(colliders);

    for (colliders) |c| {
        std.debug.assert(c != .none);
    }

    const texture_path = try std.fs.path.joinZ(gpa, &.{
        std.fs.path.dirname(path) orelse "",
        file.texture_path,
    });
    defer gpa.free(texture_path);

    const texture = try raylib.loadTexture(texture_path);
    errdefer texture.unload();

    return .{
        .origin = origin,
        .texture = texture,
        .colliders = colliders,
    };
}

pub fn unload(lb: LevelBackground, gpa: Allocator) void {
    lb.texture.unload();
    gpa.free(lb.colliders);
}

/// Returns the collider at index `idx`
/// with all transofrmations applied.
///
/// Asserts `idx` is in-bounds.
/// Asserts the collider isn't `none`.
pub fn getColliderIdx(lb: LevelBackground, idx: usize) Collider {
    var collider = lb.colliders[idx];
    switch (collider) {
        .circle => collider.circle.position = collider.circle.position.add(lb.origin),
        .rectangle => collider.rectangle.position = collider.rectangle.position.add(lb.origin),
        .rounded_rectangle => collider.rounded_rectangle.position = collider.rounded_rectangle.position.add(lb.origin),
        .none => unreachable,
    }
    return collider;
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
