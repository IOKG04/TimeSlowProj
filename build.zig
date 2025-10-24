const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const window_w = b.option(u31, "window_w", "Width of the games window") orelse 900;
    const window_h = b.option(u31, "window_h", "Height of the games window") orelse 540;
    const target_fps = b.option(u31, "target_fps", "Maximum FPS the game renders at") orelse 60;
    const draw_colliders = b.option(bool, "draw_colliders", "Draw collider boundaries") orelse false;
    const resources_path = "resources";
    const texture_path = resources_path ++ "/textures";
    const pixels_per_unit = 16;

    const options = b.addOptions();
    options.addOption(u31, "window_w", window_w);
    options.addOption(u31, "window_h", window_h);
    options.addOption(u31, "target_fps", target_fps);
    options.addOption([]const u8, "texture_path", texture_path);
    options.addOption(bool, "draw_colliders", draw_colliders);
    options.addOption(comptime_int, "pixels_per_unit", pixels_per_unit);
    // TODO:          v replace with `comptime_float` once support is added.
    options.addOption(f32, "units_per_pixel", 1.0 / @as(comptime_float, pixels_per_unit));

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    _ = raygui;
    const raylib_artifact = raylib_dep.artifact("raylib");

    const vec2_mod = b.addModule("Vec2", .{
        .root_source_file = b.path("modules/Vec2.zig"),
        .target = target,
        .optimize = optimize,
    });
    vec2_mod.addImport("raylib", raylib);

    const collision_mod = b.addModule("Collision", .{
        .root_source_file = b.path("modules/Collision.zig"),
        .target = target,
        .optimize = optimize,
    });
    collision_mod.addImport("Vec2", vec2_mod);
    collision_mod.addImport("raylib", raylib);

    const level_background_mod = b.addModule("LevelBackground", .{
        .root_source_file = b.path("modules/LevelBackground.zig"),
        .target = target,
        .optimize = optimize,
    });
    level_background_mod.addImport("Vec2", vec2_mod);
    level_background_mod.addImport("Collision", collision_mod);
    level_background_mod.addImport("raylib", raylib);

    const exe = b.addExecutable(.{
        .name = "TimeSlowProj",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addOptions("options", options);
    exe.root_module.addImport("Vec2", vec2_mod);
    exe.root_module.addImport("Collision", collision_mod);
    exe.root_module.addImport("LevelBackground", level_background_mod);
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_exe.step);

    b.installDirectory(.{
        .source_dir = b.path(resources_path),
        .exclude_extensions = &.{
            "README",
            "~",
        },
        .install_dir = .bin,
        .install_subdir = resources_path,
    });

    const level_editor = b.addExecutable(.{
        .name = "Level Editor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("level_editor.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    level_editor.linkLibrary(raylib_artifact);
    level_editor.root_module.addImport("raylib", raylib);
    level_editor.root_module.addOptions("options", options);
    level_editor.root_module.addImport("Vec2", vec2_mod);
    level_editor.root_module.addImport("Collision", collision_mod);
    level_editor.root_module.addImport("LevelBackground", level_background_mod);
    const run_level_editor = b.addRunArtifact(level_editor);
    if (b.args) |args| run_level_editor.addArgs(args);
    const run_level_editor_step = b.step("level-editor", "Run the level editor");
    run_level_editor_step.dependOn(&run_level_editor.step);

    const test_step = b.step("test", "Run program unit tests");
    const test_exe_run = b.addRunArtifact(b.addTest(.{
        .name = "TimeSlowProj tests",
        .root_module = exe.root_module,
    }));
    test_step.dependOn(&test_exe_run.step);
    const test_level_editor_run = b.addRunArtifact(b.addTest(.{
        .name = "Level Editor tests",
        .root_module = level_editor.root_module,
    }));
    test_step.dependOn(&test_level_editor_run.step);
    const test_vec2_run = b.addRunArtifact(b.addTest(.{
        .name = "Vec2 tests",
        .root_module = vec2_mod,
    }));
    test_step.dependOn(&test_vec2_run.step);
    const test_collision_run = b.addRunArtifact(b.addTest(.{
        .name = "Collision tests",
        .root_module = collision_mod,
    }));
    test_step.dependOn(&test_collision_run.step);
    const test_level_background_run = b.addRunArtifact(b.addTest(.{
        .name = "Vec2 tests",
        .root_module = level_background_mod,
    }));
    test_step.dependOn(&test_level_background_run.step);
}
