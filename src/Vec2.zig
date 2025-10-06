const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib");

const assert = std.debug.assert;

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

pub fn scale(v: Vec2, s: f32) Vec2 {
    return .{
        .x = v.x * s,
        .y = v.y * s,
    };
}

pub fn lenSq(v: Vec2) f32 {
    return v.x * v.x + v.y * v.y;
}
pub fn len(v: Vec2) f32 {
    return @sqrt(v.lenSq());
}
pub fn normalize(v: Vec2) Vec2 {
    const mag = v.len();
    assert(mag > 0.0);
    return v.scale(1.0 / mag);
}

pub fn angle(v: Vec2) f32 {
    return std.math.atan2(v.y, v.x);
}

pub fn dot(a: Vec2, b: Vec2) f32 {
    return a.x * b.x + a.y * b.y;
}

pub fn fromPolar(phi: f32, mag: f32) Vec2 {
    return .{
        .x = @cos(phi) * mag,
        .y = @sin(phi) * mag,
    };
}

pub const zero: Vec2 = .{
    .x = 0.0,
    .y = 0.0,
};
pub const one: Vec2 = .{
    .x = 1.0,
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
