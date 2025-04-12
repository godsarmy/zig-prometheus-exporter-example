const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const std_main_mod = b.createModule(.{
        .root_source_file = b.path("src/std_main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zap_main_mod = b.createModule(.{
        .root_source_file = b.path("src/zap_main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const std_exe = b.addExecutable(.{
        .name = "std_example",
        .root_module = std_main_mod,
    });

    const zap_exe = b.addExecutable(.{
        .name = "zap_example",
        .root_module = zap_main_mod,
    });
    const zap_dep = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
    });
    zap_exe.root_module.addImport("zap", zap_dep.module("zap"));

    const metrics_dep = b.dependency("metrics", .{
        .target = target,
        .optimize = optimize,
    });

    std_exe.root_module.addImport("metrics", metrics_dep.module("metrics"));
    zap_exe.root_module.addImport("metrics", metrics_dep.module("metrics"));
 
    b.installArtifact(std_exe);
    b.installArtifact(zap_exe);

    const run_cmd = b.addRunArtifact(std_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const std_exe_unit_tests = b.addTest(.{
        .root_module = std_main_mod,
    });

    const zap_exe_unit_tests = b.addTest(.{
        .root_module = zap_main_mod,
    });

    const run_std_exe_unit_tests = b.addRunArtifact(std_exe_unit_tests);
    const run_zap_exe_unit_tests = b.addRunArtifact(zap_exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_std_exe_unit_tests.step);
    test_step.dependOn(&run_zap_exe_unit_tests.step);
}
