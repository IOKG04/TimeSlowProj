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

    const options = b.addOptions();
    options.addOption(u31, "window_w", window_w);
    options.addOption(u31, "window_h", window_h);
    options.addOption(u31, "target_fps", target_fps);
    options.addOption([]const u8, "texture_path", texture_path);
    options.addOption(bool, "draw_colliders", draw_colliders);

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
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
    exe.root_module.addImport("raygui", raygui);
    exe.root_module.addOptions("options", options);
    exe.root_module.addImport("Vec2", vec2_mod);
    exe.root_module.addImport("Collision", collision_mod);
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

    const test_step = b.step("test", "Run program unit tests");
    const test_exe_run = b.addRunArtifact(b.addTest(.{
        .name = "TimeSlowProj tests",
        .root_module = exe.root_module,
    }));
    test_step.dependOn(&test_exe_run.step);
    const test_vec2_run = b.addRunArtifact(b.addTest(.{
        .name = "Vec2 tests",
        .root_module = vec2_mod,
    }));
    test_step.dependOn(&test_vec2_run.step);
}
