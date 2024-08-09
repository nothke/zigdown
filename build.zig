const std = @import("std");

const mach_glfw = @import("mach_glfw");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "glfw-test",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // allows @embedFile() from res
    //exe.main_pkg_path = .{ .path = "." };

    // Use mach-glfw
    const glfw_dep = b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));
    //@import("mach_glfw").link(glfw_dep.builder, exe);

    // zgltf
    exe.root_module.addImport("zgltf", b.dependency("zgltf", .{
        .target = target,
        .optimize = optimize,
    }).module("zgltf"));

    // gl
    exe.root_module.addImport("gl", b.createModule(.{
        .root_source_file = b.path("libs/gl41.zig"),
    }));

    // mach math
    exe.root_module.addImport("math", b.createModule(.{
        .root_source_file = b.path("libs/math/main.zig"),
    }));

    // Include C

    exe.linkLibC();
    exe.addCSourceFile(.{ .file = b.path("libs/stb_image.c"), .flags = &.{} });
    exe.addCSourceFile(.{ .file = b.path("libs/cgltf.c"), .flags = &.{} });

    exe.addIncludePath(b.path("libs"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // const unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // unit_tests.addModule("mach", @import("mach").module(mach_dep.builder, optimize, target));

    // const run_unit_tests = b.addRunArtifact(unit_tests);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_unit_tests.step);
}
