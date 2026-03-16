// Evidence Graph FFI Implementation
//
// Implements the C-compatible FFI declared in src/abi/Foreign.idr.
// Domain operations: PROMPT scoring, relationship weight propagation,
// cycle detection, audience-weighted scoring.
//
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

const std = @import("std");
const math = std.math;

const VERSION = "0.3.0";
const BUILD_INFO = "EvidenceGraph FFI built with Zig " ++ @import("builtin").zig_version_string;

/// Thread-local error storage
threadlocal var last_error: ?[]const u8 = null;

fn setError(msg: []const u8) void {
    last_error = msg;
}

fn clearError() void {
    last_error = null;
}

//==============================================================================
// Core Types (must match src/abi/Types.idr)
//==============================================================================

/// Result codes
pub const Result = enum(c_int) {
    ok = 0,
    @"error" = 1,
    invalid_param = 2,
    out_of_memory = 3,
    null_pointer = 4,
    not_found = 5,
    conflict = 6,
    graph_cycle = 7,
    score_out_of_range = 8,
};

/// Claim types
pub const ClaimType = enum(u32) {
    primary = 0,
    supporting = 1,
    counter = 2,
};

/// Evidence types
pub const EvidenceType = enum(u32) {
    document = 0,
    dataset = 1,
    interview = 2,
    media = 3,
    other = 4,
};

/// Relationship types (graph edges)
pub const RelationshipType = enum(u32) {
    supports = 0,
    contradicts = 1,
    contextualizes = 2,
};

/// Audience types for PROMPT weighting
pub const AudienceType = enum(u32) {
    researcher = 0,
    policymaker = 1,
    skeptic = 2,
    activist = 3,
    affected_person = 4,
    journalist = 5,
};

/// PROMPT scores struct — must match CPromptScores in Types.idr
/// 6 * u32 = 24 bytes, alignment 4
pub const PromptScores = extern struct {
    provenance: u32,
    replicability: u32,
    objective: u32,
    methodology: u32,
    publication: u32,
    transparency: u32,
};

/// Default PROMPT dimension weights (sum = 1.0)
const default_weights = [6]f64{ 0.20, 0.15, 0.15, 0.20, 0.15, 0.15 };

/// Audience-specific weight profiles
/// Order: provenance, replicability, objective, methodology, publication, transparency
const audience_weights = [6][6]f64{
    // researcher:      methodology + replicability heavy
    .{ 0.10, 0.30, 0.03, 0.35, 0.02, 0.20 },
    // policymaker:     provenance + publication + objective
    .{ 0.30, 0.05, 0.25, 0.10, 0.25, 0.05 },
    // skeptic:         transparency + replicability
    .{ 0.10, 0.30, 0.03, 0.20, 0.02, 0.35 },
    // activist:        provenance + objective + publication
    .{ 0.30, 0.05, 0.25, 0.15, 0.20, 0.05 },
    // affected_person: objective + provenance + transparency
    .{ 0.30, 0.02, 0.35, 0.10, 0.03, 0.20 },
    // journalist:      provenance + transparency + replicability
    .{ 0.25, 0.20, 0.10, 0.15, 0.05, 0.25 },
};

//==============================================================================
// Library Handle
//==============================================================================

const HandleState = struct {
    allocator: std.mem.Allocator,
    initialized: bool,
};

//==============================================================================
// Library Lifecycle
//==============================================================================

/// Initialize the evidence graph library
export fn evidence_graph_init() ?*anyopaque {
    const allocator = std.heap.c_allocator;

    const state = allocator.create(HandleState) catch {
        setError("Failed to allocate handle");
        return null;
    };

    state.* = .{
        .allocator = allocator,
        .initialized = true,
    };

    clearError();
    return @ptrCast(state);
}

/// Free the library handle
export fn evidence_graph_free(handle: ?*anyopaque) void {
    const ptr = handle orelse return;
    const state: *HandleState = @ptrCast(@alignCast(ptr));

    if (!state.initialized) return;

    state.initialized = false;
    state.allocator.destroy(state);
    clearError();
}

//==============================================================================
// PROMPT Score Operations
//==============================================================================

/// Calculate overall PROMPT score (weighted average).
/// Returns score * 100 (e.g. 8550 = 85.50) for fixed-point precision.
/// Returns 0xFFFFFFFF on error.
export fn evidence_graph_prompt_overall(
    handle: ?*anyopaque,
    provenance: u32,
    replicability: u32,
    objective: u32,
    methodology: u32,
    publication: u32,
    transparency: u32,
) u32 {
    const ptr = handle orelse {
        setError("Null handle");
        return 0xFFFFFFFF;
    };
    const state: *HandleState = @ptrCast(@alignCast(ptr));

    if (!state.initialized) {
        setError("Handle not initialized");
        return 0xFFFFFFFF;
    }

    const scores = [6]u32{ provenance, replicability, objective, methodology, publication, transparency };

    // Validate all scores are in range [0, 100]
    for (scores) |s| {
        if (s > 100) {
            setError("PROMPT score out of range (0-100)");
            return 0xFFFFFFFF;
        }
    }

    var total: f64 = 0.0;
    for (scores, 0..) |s, i| {
        total += @as(f64, @floatFromInt(s)) * default_weights[i];
    }

    clearError();
    return @intFromFloat(total * 100.0);
}

/// Calculate audience-weighted PROMPT score.
/// audience_type: 0-5 mapping to AudienceType enum.
/// Returns score * 100 for fixed-point precision.
export fn evidence_graph_prompt_audience(
    handle: ?*anyopaque,
    audience_type: u32,
    provenance: u32,
    replicability: u32,
    objective: u32,
    methodology: u32,
    publication: u32,
    transparency: u32,
) u32 {
    const ptr = handle orelse {
        setError("Null handle");
        return 0xFFFFFFFF;
    };
    const state: *HandleState = @ptrCast(@alignCast(ptr));

    if (!state.initialized) {
        setError("Handle not initialized");
        return 0xFFFFFFFF;
    }

    if (audience_type > 5) {
        setError("Invalid audience type (0-5)");
        return 0xFFFFFFFF;
    }

    const scores = [6]u32{ provenance, replicability, objective, methodology, publication, transparency };

    for (scores) |s| {
        if (s > 100) {
            setError("PROMPT score out of range (0-100)");
            return 0xFFFFFFFF;
        }
    }

    const weights = audience_weights[audience_type];

    var total: f64 = 0.0;
    for (scores, 0..) |s, i| {
        total += @as(f64, @floatFromInt(s)) * weights[i];
    }

    clearError();
    return @intFromFloat(total * 100.0);
}

//==============================================================================
// Relationship Operations
//==============================================================================

/// Calculate propagated weight through an evidence chain.
/// weights_ptr: pointer to array of f64 weights
/// count: number of weights in the chain
/// Returns combined weight * 1000 for fixed-point precision.
/// Chain weight = product of individual weights, clamped to [-1.0, 1.0].
export fn evidence_graph_propagated_weight(
    handle: ?*anyopaque,
    weights_ptr: ?[*]const f64,
    count: u32,
) u32 {
    const ptr = handle orelse {
        setError("Null handle");
        return 0;
    };
    const state: *HandleState = @ptrCast(@alignCast(ptr));

    if (!state.initialized) {
        setError("Handle not initialized");
        return 0;
    }

    const w_ptr = weights_ptr orelse {
        setError("Null weights pointer");
        return 0;
    };

    if (count == 0) {
        clearError();
        return 0;
    }

    const weights = w_ptr[0..count];

    var product: f64 = 1.0;
    for (weights) |w| {
        product *= w;
    }

    // Clamp to [-1.0, 1.0]
    product = @max(-1.0, @min(1.0, product));

    clearError();
    // Return as signed value encoded in u32: offset by 1000
    // -1.0 = 0, 0.0 = 1000, 1.0 = 2000
    return @intFromFloat((product + 1.0) * 1000.0);
}

/// Check if adding an edge from→to would create a cycle.
/// from_id and to_id are null-terminated C strings.
/// Returns Result.ok if no cycle, Result.graph_cycle if cycle detected.
///
/// NOTE: This is a simplified check — real cycle detection requires the
/// full graph topology from ArangoDB. This function validates that
/// from_id != to_id (self-loops) and delegates complex cycle detection
/// to the Elixir layer which has graph access.
export fn evidence_graph_check_cycle(
    handle: ?*anyopaque,
    from_id: ?[*:0]const u8,
    to_id: ?[*:0]const u8,
) c_int {
    const ptr = handle orelse {
        setError("Null handle");
        return @intFromEnum(Result.null_pointer);
    };
    const state: *HandleState = @ptrCast(@alignCast(ptr));

    if (!state.initialized) {
        setError("Handle not initialized");
        return @intFromEnum(Result.@"error");
    }

    const from = from_id orelse {
        setError("Null from_id");
        return @intFromEnum(Result.null_pointer);
    };

    const to = to_id orelse {
        setError("Null to_id");
        return @intFromEnum(Result.null_pointer);
    };

    const from_str = std.mem.span(from);
    const to_str = std.mem.span(to);

    // Self-loop detection
    if (std.mem.eql(u8, from_str, to_str)) {
        setError("Self-loop detected");
        return @intFromEnum(Result.graph_cycle);
    }

    clearError();
    return @intFromEnum(Result.ok);
}

//==============================================================================
// String Operations
//==============================================================================

/// Get a string result
export fn evidence_graph_get_string(handle: ?*anyopaque) ?[*:0]const u8 {
    const ptr = handle orelse {
        setError("Null handle");
        return null;
    };
    const state: *HandleState = @ptrCast(@alignCast(ptr));

    if (!state.initialized) {
        setError("Handle not initialized");
        return null;
    }

    const result = state.allocator.dupeZ(u8, "EvidenceGraph OK") catch {
        setError("Failed to allocate string");
        return null;
    };

    clearError();
    return result.ptr;
}

/// Free a string allocated by the library
export fn evidence_graph_free_string(str: ?[*:0]const u8) void {
    const s = str orelse return;
    const allocator = std.heap.c_allocator;
    const slice = std.mem.span(s);
    allocator.free(slice);
}

//==============================================================================
// Error Handling
//==============================================================================

/// Get the last error message
export fn evidence_graph_last_error() ?[*:0]const u8 {
    const err = last_error orelse return null;
    const allocator = std.heap.c_allocator;
    const c_str = allocator.dupeZ(u8, err) catch return null;
    return c_str.ptr;
}

//==============================================================================
// Version Information
//==============================================================================

/// Get the library version
export fn evidence_graph_version() [*:0]const u8 {
    return VERSION.ptr;
}

/// Get build information
export fn evidence_graph_build_info() [*:0]const u8 {
    return BUILD_INFO.ptr;
}

//==============================================================================
// Utility Functions
//==============================================================================

/// Check if handle is initialized
export fn evidence_graph_is_initialized(handle: ?*anyopaque) u32 {
    const ptr = handle orelse return 0;
    const state: *const HandleState = @ptrCast(@alignCast(ptr));
    return if (state.initialized) 1 else 0;
}

//==============================================================================
// Compile-time ABI verification
//==============================================================================

comptime {
    // Verify PromptScores layout matches Idris2 ABI definition
    if (@sizeOf(PromptScores) != 24) @compileError("PromptScores size mismatch (expected 24)");
    if (@alignOf(PromptScores) != 4) @compileError("PromptScores alignment mismatch (expected 4)");

    // Verify audience weights are valid probability distributions
    for (audience_weights) |weights| {
        var sum: f64 = 0.0;
        for (weights) |w| {
            sum += w;
        }
        // Allow small floating-point tolerance
        if (sum < 0.99 or sum > 1.01) {
            @compileError("Audience weight profile does not sum to 1.0");
        }
    }

    // Verify default weights sum to 1.0
    var dw_sum: f64 = 0.0;
    for (default_weights) |w| {
        dw_sum += w;
    }
    if (dw_sum < 0.99 or dw_sum > 1.01) {
        @compileError("Default weights do not sum to 1.0");
    }
}

//==============================================================================
// Tests
//==============================================================================

test "lifecycle" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    try std.testing.expect(evidence_graph_is_initialized(handle) == 1);
}

test "prompt_overall — balanced scores" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    // All 50 → overall should be 50.00 → 5000
    const result = evidence_graph_prompt_overall(handle, 50, 50, 50, 50, 50, 50);
    try std.testing.expectEqual(@as(u32, 5000), result);
}

test "prompt_overall — max scores" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    // All 100 → overall = 100.00 → 10000
    const result = evidence_graph_prompt_overall(handle, 100, 100, 100, 100, 100, 100);
    try std.testing.expectEqual(@as(u32, 10000), result);
}

test "prompt_overall — out of range" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_prompt_overall(handle, 101, 50, 50, 50, 50, 50);
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), result);
}

test "prompt_audience — researcher weights methodology" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    // High methodology (100), low everything else (0)
    // researcher weights: methodology=0.35
    const result = evidence_graph_prompt_audience(handle, 0, 0, 0, 0, 100, 0, 0);
    try std.testing.expectEqual(@as(u32, 3500), result);
}

test "prompt_audience — invalid audience type" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_prompt_audience(handle, 99, 50, 50, 50, 50, 50, 50);
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), result);
}

test "propagated_weight — single hop" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const weights = [_]f64{0.8};
    const result = evidence_graph_propagated_weight(handle, &weights, 1);
    // 0.8 → encoded as (0.8 + 1.0) * 1000 = 1800
    try std.testing.expectEqual(@as(u32, 1800), result);
}

test "propagated_weight — multi hop" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const weights = [_]f64{ 0.9, 0.8 };
    const result = evidence_graph_propagated_weight(handle, &weights, 2);
    // 0.9 * 0.8 = 0.72 → (0.72 + 1.0) * 1000 = 1720
    try std.testing.expectEqual(@as(u32, 1720), result);
}

test "check_cycle — self loop" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_check_cycle(handle, "claim_1", "claim_1");
    try std.testing.expectEqual(@as(c_int, 7), result); // graph_cycle = 7
}

test "check_cycle — different nodes" {
    const handle = evidence_graph_init() orelse return error.InitFailed;
    defer evidence_graph_free(handle);

    const result = evidence_graph_check_cycle(handle, "claim_1", "evidence_2");
    try std.testing.expectEqual(@as(c_int, 0), result); // ok = 0
}

test "check_cycle — null handle" {
    const result = evidence_graph_check_cycle(null, "a", "b");
    try std.testing.expectEqual(@as(c_int, 4), result); // null_pointer = 4
}

test "error handling" {
    _ = evidence_graph_prompt_overall(null, 0, 0, 0, 0, 0, 0);
    const err = evidence_graph_last_error();
    try std.testing.expect(err != null);

    if (err) |e| {
        const allocator = std.heap.c_allocator;
        const err_str = std.mem.span(e);
        try std.testing.expect(err_str.len > 0);
        allocator.free(err_str);
    }
}

test "version" {
    const ver = evidence_graph_version();
    const ver_str = std.mem.span(ver);
    try std.testing.expectEqualStrings(VERSION, ver_str);
}

test "PromptScores layout" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(PromptScores));
    try std.testing.expectEqual(@as(usize, 4), @alignOf(PromptScores));
}
