// Evidence Graph FFI Build Configuration
// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the root module for the library
    const lib_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Shared library (.so, .dylib, .dll)
    const lib = b.addLibrary(.{
        .name = "evidence_graph",
        .root_module = lib_module,
        .linkage = .dynamic,
        .version = .{ .major = 0, .minor = 3, .patch = 0 },
    });

    // Static library (.a)
    const lib_static = b.addLibrary(.{
        .name = "evidence_graph",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });

    // Install artifacts
    b.installArtifact(lib);
    b.installArtifact(lib_static);

    // Install header file
    const header_install = b.addInstallHeaderFile(
        b.path("include/evidence_graph.h"),
        "evidence_graph.h",
    );
    b.getInstallStep().dependOn(&header_install.step);

    // Unit tests (from main.zig)
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);

    // Integration tests
    const integration_module = b.createModule(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const integration_tests = b.addTest(.{
        .root_module = integration_module,
    });

    integration_tests.linkLibrary(lib);

    const run_integration_tests = b.addRunArtifact(integration_tests);

    const integration_test_step = b.step("test-integration", "Run integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);
}
