const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib");

const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const pi = std.math.pi;

const Vec2 = @This();

x: f32 = 0.0,
y: f32 = 0.0,

comptime { @setFloatMode(.optimized); }

pub fn add(a: Vec2, b: Vec2) Vec2 {
    return .{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}
pub fn subtract(a: Vec2, b: Vec2) Vec2 {
    return .{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}
pub fn multiply(a: Vec2, b: Vec2) Vec2 {
    return .{
        .x = a.x * b.x,
        .y = a.y * b.y,
    };
}
pub fn divide(a: Vec2, b: Vec2) Vec2 {
    return .{
        .x = a.x / b.x,
        .y = a.y / b.y,
    };
}

pub fn scale(v: Vec2, s: f32) Vec2 {
    return .{
        .x = v.x * s,
        .y = v.y * s,
    };
}

pub fn abs(v: Vec2) Vec2 {
    return .{
        .x = @abs(v.x),
        .y = @abs(v.y),
    };
}

pub fn lenSq(v: Vec2) f32 {
    return v.x * v.x + v.y * v.y;
}
pub fn len(v: Vec2) f32 {
    return @sqrt(v.lenSq());
}
/// Asserts `v.len() > 0.0`.
pub fn normalize(v: Vec2) Vec2 {
    const mag = v.len();
    assert(mag > 0.0);
    return v.scale(1.0 / mag);
}
/// Returns `null` if `v.len() <= 0.0`.
pub fn normalizeSafe(v: Vec2) ?Vec2 {
    const mag = v.len();
    if (mag <= 0.0) return null;
    return v.scale(1.0 / mag);
}
test normalizeSafe {
    try expectEqual(Vec2{ .x = 1.0, .y = 0.0 }, (Vec2{ .x = 1.0, .y = 0.0 }).normalizeSafe().?);
    try expectEqual(Vec2{ .x = 1.0, .y = 0.0 }, (Vec2{ .x = 2.0, .y = 0.0 }).normalizeSafe().?);
    try expectEqual(Vec2{ .x = 0.0, .y = 1.0 }, (Vec2{ .x = 0.0, .y = 1.0 }).normalizeSafe().?);
    try expectEqual(Vec2{ .x = 0.0, .y = 1.0 }, (Vec2{ .x = 0.0, .y = 2.0 }).normalizeSafe().?);

    try expectEqual(null, (Vec2{ .x = 0.0, .y = 0.0 }).normalizeSafe());
}

pub fn angle(v: Vec2) f32 {
    return std.math.atan2(v.y, v.x);
}
test angle {
    const tollerance = 0.001;
    try expectApproxEqAbs(0, angle(.{ .x = 1.0, .y = 0.0 }), tollerance);
    try expectApproxEqAbs(pi * 0.5, angle(.{ .x = 0.0, .y = 1.0 }), tollerance);
    try expectApproxEqAbs(pi, angle(.{ .x = -1.0, .y = 0.0 }), tollerance);
    try expectApproxEqAbs(-pi * 0.5, angle(.{ .x = 0.0, .y = -1.0 }), tollerance);

    try expectApproxEqAbs(0, angle(.{ .x = 2.0, .y = 0.0 }), tollerance);
    try expectApproxEqAbs(pi * 0.25, angle(.{ .x = 1.0, .y = 1.0 }), tollerance);
}

/// Returns vector of length `1.0`.
pub fn fromAngle(phi: f32) Vec2 {
    return .{
        .x = @cos(phi),
        .y = @sin(phi),
    };
}
pub fn fromPolar(phi: f32, mag: f32) Vec2 {
    return fromAngle(phi).scale(mag);
}

pub fn dot(a: Vec2, b: Vec2) f32 {
    return a.x * b.x + a.y * b.y;
}

/// Returns `v`s length if it were project onto `p`.
/// Asserts `p.len() > 0.0`.
pub fn projectOnto(v: Vec2, p: Vec2) f32 {
    const p_mag = p.len();
    assert(p_mag > 0.0);
    return p.dot(v) / p_mag;
}
test projectOnto {
    try expectEqual(1.0, projectOnto(.{ .x = 1.0, .y = 0.0 }, .{ .x = 1.0, .y = 0.0 }));
    try expectEqual(1.0, projectOnto(.{ .x = 1.0, .y = 1.0 }, .{ .x = 1.0, .y = 0.0 }));
    try expectEqual(1.0, projectOnto(.{ .x = 1.0, .y = 0.0 }, .{ .x = 2.0, .y = 0.0 }));

    try expectEqual(1.0, projectOnto(.{ .x = 0.0, .y = 1.0 }, .{ .x = 0.0, .y = 1.0 }));
    try expectEqual(1.0, projectOnto(.{ .x = 1.0, .y = 1.0 }, .{ .x = 0.0, .y = 1.0 }));
    try expectEqual(1.0, projectOnto(.{ .x = 0.0, .y = 1.0 }, .{ .x = 0.0, .y = 2.0 }));

    try expectEqual(-1.0, projectOnto(.{ .x = -1.0, .y = 0.0 }, .{ .x = 1.0, .y = 0.0 }));
    try expectEqual(-2.0, projectOnto(.{ .x = -2.0, .y = 0.0 }, .{ .x = 1.0, .y = 0.0 }));
    try expectEqual(-1.0, projectOnto(.{ .x = 1.0, .y = 0.0 }, .{ .x = -1.0, .y = 0.0 }));
    try expectEqual(-2.0, projectOnto(.{ .x = 2.0, .y = 0.0 }, .{ .x = -1.0, .y = 0.0 }));

    try expectEqual(@sqrt(2.0) / 2.0, projectOnto(.{ .x = 1.0, .y = 0.0 }, .{ .x = 1.0, .y = 1.0 }));
    try expectEqual(@sqrt(2.0) / 2.0, projectOnto(.{ .x = 0.0, .y = 1.0 }, .{ .x = 1.0, .y = 1.0 }));
    try expectEqual(-@sqrt(2.0) / 2.0, projectOnto(.{ .x = 1.0, .y = 0.0 }, .{ .x = -1.0, .y = -1.0 }));
    try expectEqual(-@sqrt(2.0) / 2.0, projectOnto(.{ .x = 0.0, .y = -1.0 }, .{ .x = 1.0, .y = 1.0 }));
}
/// Returns `v`s length if it were project onto `p`.
/// Assumes `p.len() == 1.0`.
pub fn projectOntoNormalized(v: Vec2, p: Vec2) f32 {
    // An `assert(p.len() == 1.0);` doesn't work here because things may be inexact.
    return p.dot(v);
}

pub fn rotate(v: Vec2, phi: f32) Vec2 {
    return .{
        .x = @cos(phi) * v.x - @sin(phi) * v.y,
        .y = @sin(phi) * v.x + @cos(phi) * v.y,
    };
}
pub fn rotateAround(v: Vec2, c: Vec2, phi: f32) Vec2 {
    const diff = v.subtract(c);
    return diff.rotate(phi).add(c);
}
test rotateAround {
    const tol = 0.001;
    const cor: Vec2 = .{ .x = 2.0, .y = 1.0 };

    try expectApproxEqAbsVec2(Vec2{ .x = 1.0, .y = 1.0 }, rotateAround(.{ .x = 1.0, .y = 1.0 }, cor, 0.0 * pi), tol);
    try expectApproxEqAbsVec2(Vec2{ .x = 2.0, .y = 0.0 }, rotateAround(.{ .x = 1.0, .y = 1.0 }, cor, 0.5 * pi), tol);
    try expectApproxEqAbsVec2(Vec2{ .x = 3.0, .y = 1.0 }, rotateAround(.{ .x = 1.0, .y = 1.0 }, cor, 1.0 * pi), tol);
    try expectApproxEqAbsVec2(Vec2{ .x = 2.0, .y = 2.0 }, rotateAround(.{ .x = 1.0, .y = 1.0 }, cor, 1.5 * pi), tol);
}

pub const zero: Vec2 = .{
    .x = 0.0,
    .y = 0.0,
};
pub const one: Vec2 = .{
    .x = 1.0,
    .y = 1.0,
};
pub const unit_x: Vec2 = .{
    .x = 1.0,
    .y = 0.0,
};
pub const unit_y: Vec2 = .{
    .x = 0.0,
    .y = 1.0,
};

pub fn toRaylib(v: Vec2) raylib.Vector2 {
    return .{
        .x = v.x,
        .y = v.y,
    };
}
pub fn fromRaylib(v: raylib.Vector2) Vec2 {
    return .{
        .x = v.x,
        .y = v.y,
    };
}

fn expectApproxEqAbsVec2(expected: Vec2, actual: Vec2, tollerance: f32) !void {
    try expectApproxEqAbs(expected.x, actual.x, tollerance);
    try expectApproxEqAbs(expected.y, actual.y, tollerance);
}
