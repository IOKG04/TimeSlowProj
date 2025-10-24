const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const game = @import("game.zig");

pub const log = std.log.scoped(.time_slow_proj);

pub var args: []const [:0]const u8 = undefined;

pub fn main() !void {
    const using_c_allocator = builtin.link_libc and builtin.mode != .Debug;
    var dbg_allocator = if (using_c_allocator) {} else std.heap.DebugAllocator(.{}).init;
    defer { if (!using_c_allocator) _ = dbg_allocator.deinit(); }
    const gpa = if (using_c_allocator) std.heap.c_allocator else dbg_allocator.allocator();

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    args = try std.process.argsAlloc(arena);

    log.info("initializing game", .{});

    try game.init(gpa, arena);
    defer game.close(gpa, arena);

    log.info("running game", .{});

    try game.run(gpa, arena);
}

comptime {
    std.debug.assert(options.window_w > 0);
    std.debug.assert(options.window_h > 0);
    std.debug.assert(options.target_fps > 0);
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
