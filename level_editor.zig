const std = @import("std");
const options = @import("options");
const raylib = @import("raylib");
const LevelBackground = @import("LevelBackground");
const Collider = @import("Collision").Collider;
const Vec2 = @import("Vec2");

pub const log = std.log.scoped(.level_editor);

var camera_speed: f32 = 5.0;

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    const program_name = args.next().?;

    const level_path = blk: {
        const arg = args.next() orelse {
            log.err("too few arguments", .{});
            try printHelp(stdout, program_name);
            return error.TooFewArguments;
        };
        if (std.mem.eql(u8, "--help", arg)) {
            try printHelp(stdout, program_name);
            return;
        }
        break :blk arg;
    };

    var colliders: std.ArrayList(Collider) = .empty;
    defer colliders.deinit(gpa);

    const texture_path: []const u8 = blk: {
        if (args.next()) |image_path| {
            const relative = try std.fs.path.relative(gpa, std.fs.path.dirname(level_path) orelse ".", image_path);
            errdefer gpa.free(relative);
            break :blk relative;
        } else { // `texture_path` must be read from file.
            const level_file_contents: [:0]const u8 = clk: {
                const file = try std.fs.cwd().openFile(level_path, .{ .mode = .read_only });
                defer file.close();

                var file_reader_buffer: [256]u8 = undefined;
                var file_reader_outer = file.reader(&file_reader_buffer);
                const file_reader = &file_reader_outer.interface;

                const contents = try file_reader.allocRemaining(gpa, .unlimited);
                defer gpa.free(contents);

                const contents_sentinel = try std.fmt.allocPrintSentinel(gpa, "{s}", .{contents}, 0);
                errdefer gpa.free(contents_sentinel);
                break :clk contents_sentinel;
            };
            defer gpa.free(level_file_contents);

            const level_from_file = try std.zon.parse.fromSlice(LevelBackground.File, gpa, level_file_contents, null, .{});
            defer std.zon.parse.free(gpa, level_from_file);

            try colliders.appendSlice(gpa, level_from_file.colliders);
            break :blk try gpa.dupe(u8, level_from_file.texture_path);
        }
    };
    defer gpa.free(texture_path);

    raylib.initWindow(options.window_w, options.window_h, "Level Editor");
    while (!raylib.isWindowReady()) {
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
    defer raylib.closeWindow();
    raylib.setTargetFPS(options.target_fps);

    const texture: raylib.Texture2D = blk: {
        const path = try std.fs.path.joinZ(gpa, &.{
            std.fs.path.dirname(level_path) orelse ".",
            texture_path,
        });
        defer gpa.free(path);
        break :blk try raylib.loadTexture(path);
    };
    defer texture.unload();

    var camera: raylib.Camera2D = .{
        .offset = .{ .x = @abs(options.window_w) / 2, .y = @abs(options.window_h) / 2 },
        .target = .{ .x = 0.0, .y = 0.0 },
        .rotation = 0.0,
        .zoom = @as(f32, @floatFromInt(options.window_h)) / 8.0,
    };

    var active_collider: Collider = .none;
    _ = &active_collider;
    var collider_type: @typeInfo(Collider).@"union".tag_type.? = .rectangle;

    var click_start: Vec2 = undefined;

    while (!raylib.windowShouldClose()) {
        const dt = raylib.getFrameTime();

        if (raylib.isKeyDown(.w)) camera.target.y -= camera_speed * dt;
        if (raylib.isKeyDown(.s)) camera.target.y += camera_speed * dt;
        if (raylib.isKeyDown(.a)) camera.target.x -= camera_speed * dt;
        if (raylib.isKeyDown(.d)) camera.target.x += camera_speed * dt;

        if (raylib.isKeyPressed(.e)) {
            camera.zoom *= 2.0;
            camera_speed /= 2.0;
        }
        if (raylib.isKeyPressed(.q)) {
            camera.zoom /= 2.0;
            camera_speed *= 2.0;
        }

        if (raylib.isKeyPressed(.one)) collider_type = .rectangle;
        if (raylib.isKeyPressed(.two)) collider_type = .circle;
        if (raylib.isKeyPressed(.three)) collider_type = .rounded_rectangle;

        const mouse_screen_raylib = raylib.getMousePosition();
        const mouse_world_raylib = raylib.getScreenToWorld2D(mouse_screen_raylib, camera);
        const mouse_world: Vec2 = .fromRaylib(mouse_world_raylib);
        const mouse_world_grid = mouse_world.snapToGrid(switch (collider_type) {
            .circle => options.units_per_pixel / 2.0,
            .rectangle, .rounded_rectangle => options.units_per_pixel,
            else => unreachable,
        });

        if (raylib.isMouseButtonPressed(.left)) {
            click_start = mouse_world_grid;
            switch (collider_type) {
                .rectangle => active_collider = .{ .rectangle = .{
                    .position = click_start,
                    .scale = .zero,
                } },
                .circle => active_collider = .{ .circle = .{
                    .position = click_start,
                    .radius = 0.0,
                } },
                .rounded_rectangle => active_collider = .{ .rounded_rectangle = .{
                    .position = click_start,
                    .scale = .zero,
                    .radius = 0.0,
                } },
                else => unreachable,
            }
        }
        if (raylib.isMouseButtonReleased(.left)) {
            try colliders.append(gpa, active_collider);
            active_collider = .none;
        }

        switch (active_collider) {
            .none => {},
            .rectangle => {
                active_collider = .{ .rectangle = .{
                    .position = click_start.add(mouse_world_grid).scale(0.5),
                    .scale = click_start.subtract(mouse_world_grid).abs(),
                } };
            },
            .circle =>  {
                active_collider = .{ .circle = .{
                    .position = click_start,
                    .radius = click_start.subtract(mouse_world_grid).len(),
                } };
            },
            .rounded_rectangle => {
                var radius = active_collider.rounded_rectangle.radius;
                if (raylib.isKeyPressed(.comma)) radius -= options.units_per_pixel;
                if (raylib.isKeyPressed(.period)) radius += options.units_per_pixel;
                radius = @max(radius, 0.0);

                active_collider = .{ .rounded_rectangle = .{
                    .position = click_start.add(mouse_world_grid).scale(0.5),
                    .scale = click_start.subtract(mouse_world_grid).abs(),
                    .radius = radius,
                } };
            },
        }

        if (raylib.isKeyPressed(.backspace)) _ = colliders.pop();
        if (raylib.isKeyPressed(.enter)) try save(level_path, texture_path, colliders.items);

        // zig fmt: off
        raylib.beginDrawing();
            raylib.clearBackground(.dark_gray);
            camera.begin();
                texture.drawEx(.{ .x = 0.0, .y = 0.0 }, 0.0, options.units_per_pixel, .white);
                for (colliders.items) |c| {
                    c.draw();
                }
                if (active_collider != .none) active_collider.draw();
            camera.end();
            raylib.drawFPS(0, 0);
            raylib.drawText(@tagName(collider_type), 0, 20, 20, .red);
        raylib.endDrawing();
        // zig fmt: on
    }

    try save(level_path, texture_path, colliders.items);
}

fn printHelp(stdout: *std.Io.Writer, program_name: []const u8) std.Io.Writer.Error!void {
    try stdout.print(
        \\
        \\TimeSlowProj > Level Editor
        \\
        \\Usage:
        \\ {s} [level]          Open [level].
        \\ {s} [level] [image]  Create [level] and set its image to be [image].
        \\ {s} --help           Print this help message.
        \\
        , .{
            program_name,
            program_name,
            program_name,
        },
    );
    try stdout.flush();
}

fn save(level_path: []const u8, texture_path: []const u8, colliders: []const Collider) !void {
    const level_file: LevelBackground.File = .{
        .texture_path = texture_path,
        .colliders = colliders,
    };
    const outp_file = try std.fs.cwd().createFile(level_path, .{});
    defer outp_file.close();
    var outp_writer_buffer: [256]u8 = undefined;
    var outp_writer = outp_file.writer(&outp_writer_buffer);
    const outp = &outp_writer.interface;
    
    try std.zon.stringify.serialize(level_file, .{}, outp);

    try outp_writer.end();

    log.info("saved to {s}", .{level_path});
}
