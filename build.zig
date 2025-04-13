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

    const httpz_main_mod = b.createModule(.{
        .root_source_file = b.path("src/httpz_main.zig"),
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

    const httpz_exe = b.addExecutable(.{
        .name = "httpz_example",
        .root_module = httpz_main_mod,
    });

    const zap_dep = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
    });
    zap_exe.root_module.addImport("zap", zap_dep.module("zap"));

    const httpz_dep = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    httpz_exe.root_module.addImport("httpz", httpz_dep.module("httpz"));

    const metrics_dep = b.dependency("metrics", .{
        .target = target,
        .optimize = optimize,
    });

    std_exe.root_module.addImport("metrics", metrics_dep.module("metrics"));
    zap_exe.root_module.addImport("metrics", metrics_dep.module("metrics"));
    httpz_exe.root_module.addImport("metrics", metrics_dep.module("metrics"));

    b.installArtifact(std_exe);
    b.installArtifact(zap_exe);
    b.installArtifact(httpz_exe);

    const run_std_cmd = b.addRunArtifact(std_exe);
    run_std_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_std_cmd.addArgs(args);
    }
    const run_std_step = b.step("run-std", "Run std.http app");
    run_std_step.dependOn(&run_std_cmd.step);

    const run_zap_cmd = b.addRunArtifact(zap_exe);
    run_zap_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_zap_cmd.addArgs(args);
    }
    const run_zap_step = b.step("run-zap", "Run zap apps");
    run_zap_step.dependOn(&run_zap_cmd.step);

    const run_httpz_cmd = b.addRunArtifact(httpz_exe);
    run_httpz_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_httpz_cmd.addArgs(args);
    }
    const run_httpz_step = b.step("run-httpz", "Run httpz apps");
    run_httpz_step.dependOn(&run_httpz_cmd.step);

    const std_exe_unit_tests = b.addTest(.{
        .root_module = std_main_mod,
    });

    const zap_exe_unit_tests = b.addTest(.{
        .root_module = zap_main_mod,
    });

    const httpz_exe_unit_tests = b.addTest(.{
        .root_module = httpz_main_mod,
    });

    const run_std_exe_unit_tests = b.addRunArtifact(std_exe_unit_tests);
    const run_zap_exe_unit_tests = b.addRunArtifact(zap_exe_unit_tests);
    const run_httpz_exe_unit_tests = b.addRunArtifact(httpz_exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_std_exe_unit_tests.step);
    test_step.dependOn(&run_zap_exe_unit_tests.step);
    test_step.dependOn(&run_httpz_exe_unit_tests.step);
}
