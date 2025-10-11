const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const window_w = b.option(u31, "window_w", "Width of the games window") orelse 600;
    const window_h = b.option(u31, "window_h", "Height of the games window") orelse 360;
    const target_fps = b.option(u31, "target_fps", "Maximum FPS the game renders at") orelse 60;
    const texture_path = "resources/textures";

    const options = b.addOptions();
    options.addOption(u31, "window_w", window_w);
    options.addOption(u31, "window_h", window_h);
    options.addOption(u31, "target_fps", target_fps);
    options.addOption([]const u8, "texture_path", texture_path);

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

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
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_exe.step);

    const test_exe = b.addTest(.{
        .name = "TimeSlowProj tests",
        .root_module = exe.root_module,
    });
    const test_exe_run = b.addRunArtifact(test_exe);
    const test_exe_step = b.step("test", "Run program unit tests");
    test_exe_step.dependOn(&test_exe_run.step);

    b.installDirectory(.{
        .source_dir = b.path("resources"),
        .install_dir = .bin,
        .install_subdir = "resources",
    });
}
