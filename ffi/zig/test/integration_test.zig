// Evidence Graph Integration Tests
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// These tests verify that the Zig FFI correctly implements the Idris2 ABI
// for Evidence Graph domain operations.

const std = @import("std");
const testing = std.testing;

// Import FFI functions
extern fn evidence_graph_init() ?*anyopaque;
extern fn evidence_graph_free(?*anyopaque) void;
extern fn evidence_graph_is_initialized(?*anyopaque) u32;
extern fn evidence_graph_version() [*:0]const u8;
extern fn evidence_graph_build_info() [*:0]const u8;
extern fn evidence_graph_last_error() ?[*:0]const u8;
extern fn evidence_graph_get_string(?*anyopaque) ?[*:0]const u8;
extern fn evidence_graph_free_string(?[*:0]const u8) void;
extern fn evidence_graph_prompt_overall(?*anyopaque, u32, u32, u32, u32, u32, u32) u32;
extern fn evidence_graph_prompt_audience(?*anyopaque, u32, u32, u32, u32, u32, u32, u32) u32;
extern fn evidence_graph_propagated_weight(?*anyopaque, ?[*]const f64, u32) u32;
extern fn evidence_graph_check_cycle(?*anyopaque, ?[*:0]const u8, ?[*:0]const u8) c_int;

//==============================================================================
// Lifecycle Tests
//==============================================================================

test "create and destroy handle" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    try testing.expect(handle != null);
}

test "handle is initialized" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    try testing.expectEqual(@as(u32, 1), evidence_graph_is_initialized(handle));
}

test "null handle is not initialized" {
    try testing.expectEqual(@as(u32, 0), evidence_graph_is_initialized(null));
}

test "free null is safe" {
    evidence_graph_free(null);
}

//==============================================================================
// PROMPT Score Tests
//==============================================================================

test "prompt overall — balanced 50s gives 5000" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_prompt_overall(handle, 50, 50, 50, 50, 50, 50);
    try testing.expectEqual(@as(u32, 5000), result);
}

test "prompt overall — all zeros gives 0" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_prompt_overall(handle, 0, 0, 0, 0, 0, 0);
    try testing.expectEqual(@as(u32, 0), result);
}

test "prompt overall — all 100s gives 10000" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_prompt_overall(handle, 100, 100, 100, 100, 100, 100);
    try testing.expectEqual(@as(u32, 10000), result);
}

test "prompt overall — null handle returns error sentinel" {
    const result = evidence_graph_prompt_overall(null, 50, 50, 50, 50, 50, 50);
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), result);
}

test "prompt overall — score out of range (101)" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_prompt_overall(handle, 101, 50, 50, 50, 50, 50);
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), result);
}

test "prompt audience — researcher emphasises methodology" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    // researcher(0): methodology=0.35, replicability=0.30
    // Score: only methodology=100, rest=0 → 100*0.35 = 35.00 → 3500
    const result = evidence_graph_prompt_audience(handle, 0, 0, 0, 0, 100, 0, 0);
    try testing.expectEqual(@as(u32, 3500), result);
}

test "prompt audience — policymaker emphasises provenance" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    // policymaker(1): provenance=0.30
    // Score: only provenance=100, rest=0 → 100*0.30 = 30.00 → 3000
    const result = evidence_graph_prompt_audience(handle, 1, 100, 0, 0, 0, 0, 0);
    try testing.expectEqual(@as(u32, 3000), result);
}

test "prompt audience — skeptic emphasises transparency" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    // skeptic(2): transparency=0.35
    const result = evidence_graph_prompt_audience(handle, 2, 0, 0, 0, 0, 0, 100);
    try testing.expectEqual(@as(u32, 3500), result);
}

test "prompt audience — invalid audience type" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_prompt_audience(handle, 99, 50, 50, 50, 50, 50, 50);
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), result);
}

test "prompt audience — all audiences, balanced scores" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    // All scores 50 → any audience weight × 50 summed should = 50.00 → 5000
    var audience_type: u32 = 0;
    while (audience_type <= 5) : (audience_type += 1) {
        const result = evidence_graph_prompt_audience(handle, audience_type, 50, 50, 50, 50, 50, 50);
        try testing.expectEqual(@as(u32, 5000), result);
    }
}

//==============================================================================
// Relationship Weight Tests
//==============================================================================

test "propagated weight — single hop 0.8" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const weights = [_]f64{0.8};
    const result = evidence_graph_propagated_weight(handle, &weights, 1);
    // (0.8 + 1.0) * 1000 = 1800
    try testing.expectEqual(@as(u32, 1800), result);
}

test "propagated weight — two hops 0.9 * 0.8 = 0.72" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const weights = [_]f64{ 0.9, 0.8 };
    const result = evidence_graph_propagated_weight(handle, &weights, 2);
    // (0.72 + 1.0) * 1000 = 1720
    try testing.expectEqual(@as(u32, 1720), result);
}

test "propagated weight — contradiction chain" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const weights = [_]f64{ 0.9, -0.7 };
    const result = evidence_graph_propagated_weight(handle, &weights, 2);
    // 0.9 * -0.7 = -0.63 → (-0.63 + 1.0) * 1000 = 370
    try testing.expectEqual(@as(u32, 370), result);
}

test "propagated weight — empty chain returns 0" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_propagated_weight(handle, null, 0);
    try testing.expectEqual(@as(u32, 0), result);
}

test "propagated weight — null handle" {
    const weights = [_]f64{0.5};
    const result = evidence_graph_propagated_weight(null, &weights, 1);
    try testing.expectEqual(@as(u32, 0), result);
}

//==============================================================================
// Cycle Detection Tests
//==============================================================================

test "check cycle — self loop detected" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_check_cycle(handle, "claim_1", "claim_1");
    try testing.expectEqual(@as(c_int, 7), result); // graph_cycle
}

test "check cycle — different nodes ok" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_check_cycle(handle, "claim_1", "evidence_2");
    try testing.expectEqual(@as(c_int, 0), result); // ok
}

test "check cycle — null from_id" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_check_cycle(handle, null, "evidence_2");
    try testing.expectEqual(@as(c_int, 4), result); // null_pointer
}

test "check cycle — null to_id" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_check_cycle(handle, "claim_1", null);
    try testing.expectEqual(@as(c_int, 4), result); // null_pointer
}

test "check cycle — null handle" {
    const result = evidence_graph_check_cycle(null, "a", "b");
    try testing.expectEqual(@as(c_int, 4), result); // null_pointer
}

//==============================================================================
// String Tests
//==============================================================================

test "get string result" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const str = evidence_graph_get_string(handle);
    defer if (str) |s| evidence_graph_free_string(s);

    try testing.expect(str != null);
    if (str) |s| {
        const text = std.mem.span(s);
        try testing.expectEqualStrings("EvidenceGraph OK", text);
    }
}

test "get string with null handle" {
    const str = evidence_graph_get_string(null);
    try testing.expect(str == null);
}

//==============================================================================
// Error Handling Tests
//==============================================================================

test "last error after null handle PROMPT call" {
    _ = evidence_graph_prompt_overall(null, 0, 0, 0, 0, 0, 0);

    const err = evidence_graph_last_error();
    try testing.expect(err != null);

    if (err) |e| {
        const allocator = std.heap.c_allocator;
        const err_str = std.mem.span(e);
        try testing.expect(err_str.len > 0);
        allocator.free(err_str);
    }
}

//==============================================================================
// Version Tests
//==============================================================================

test "version string is semantic version" {
    const ver = evidence_graph_version();
    const ver_str = std.mem.span(ver);

    try testing.expect(ver_str.len > 0);
    try testing.expect(std.mem.count(u8, ver_str, ".") >= 1);
}

test "build info contains Zig" {
    const info = evidence_graph_build_info();
    const info_str = std.mem.span(info);

    try testing.expect(std.mem.indexOf(u8, info_str, "Zig") != null);
}

//==============================================================================
// Memory Safety Tests
//==============================================================================

test "multiple handles are independent" {
    const h1 = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(h1);

    const h2 = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(h2);

    try testing.expect(h1 != h2);

    // Operations on h1 should not affect h2
    _ = evidence_graph_prompt_overall(h1, 100, 100, 100, 100, 100, 100);
    _ = evidence_graph_prompt_overall(h2, 0, 0, 0, 0, 0, 0);
}
