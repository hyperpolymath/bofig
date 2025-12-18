// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// Build configuration for bofig documentation site
// Uses zigzag-ssg for static site generation

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Reference zigzag-ssg from tools directory
    const zigzag_dep = b.dependency("zigzag-ssg", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "bofig-site",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zigzag", zigzag_dep.module("zigzag"));

    b.installArtifact(exe);

    // Build command
    const build_cmd = b.addRunArtifact(exe);
    build_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        build_cmd.addArgs(args);
    }

    const build_step = b.step("site", "Build the documentation site");
    build_step.dependOn(&build_cmd.step);

    // Watch command for development
    const watch_step = b.step("watch", "Watch for changes and rebuild");
    watch_step.dependOn(&build_cmd.step);

    // Test step
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
