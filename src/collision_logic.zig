//! Uses optimized float mode.

const std = @import("std");
const math = std.math;
const mem = std.mem;

const GameObject = @import("GameObject.zig");
const Vec2 = @import("Vec2.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const CollisionLayer = GameObject.CollisionLayer;
const CollisionInfo = GameObject.CollisionInfo;
const pi = math.pi;

const log = @import("main.zig").log;

comptime { @setFloatMode(.optimized); }

/// If the objects are colliding, returns
/// the collision info for `self` and `other`.
/// Otherwise returns `null`.
///
/// Asserts both objects have colliders.
pub fn getCollisionInfos(self: GameObject, other: GameObject) ?[2]CollisionInfo {
    assert(self.collider != .none);
    assert(other.collider != .none);

    const layers = self.collision_layer.collidingLayers(other.collision_layer) orelse return null;

    switch (self.collider) {
        .circle => switch (other.collider) {
            .circle => return circleCircleCollision(self, other, layers),
            .rectangle => return circleRectangleCollision(self, other, layers),
            .rounded_rectangle => return circleRoundedCollision(self, other, layers),
            .none => unreachable,
        },
        .rectangle => switch (other.collider) {
            .circle => { // switch order
                const cr_collision = circleRectangleCollision(other, self, layers) orelse return null;
                return .{
                    cr_collision[1],
                    cr_collision[0],
                };
            },
            .rectangle => return rectangleRectangleCollision(self, other, layers),
            .rounded_rectangle => return rectangleRoundedCollision(self, other, layers),
            .none => unreachable,
        },
        .rounded_rectangle => switch (other.collider) {
            .circle => { // switch order
                const cr_collision = circleRoundedCollision(other, self, layers) orelse return null;
                return .{
                    cr_collision[1],
                    cr_collision[0],
                };
            },
            .rectangle => { // switch order
                const rr_collision = rectangleRoundedCollision(other, self, layers) orelse return null;
                return .{
                    rr_collision[1],
                    rr_collision[0],
                };
            },
            .rounded_rectangle => return roundedRoundedCollision(self, other, layers),
            .none => unreachable,
        },
        .none => unreachable,
    }

    return null;
}

/// Asserts `a.collider` and `b.collider` are both `.circle`.
fn circleCircleCollision(a: GameObject, b: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const a_circle = a.collider.circle;
    const b_circle = b.collider.circle;

    const a_center = a_circle.position.multiply(a.transform.scale).rotate(a.transform.rotation).add(a.transform.position);
    const b_center = b_circle.position.multiply(b.transform.scale).rotate(b.transform.rotation).add(b.transform.position);
    const distance = a_center.subtract(b_center).len();

    const a_radius = a_circle.scale.x * a.transform.scale.x / 2.0;
    assert(a_radius >= 0.0);
    const b_radius = b_circle.scale.x * b.transform.scale.x / 2.0;
    assert(b_radius >= 0.0);
    const max_distance = a_radius + b_radius;

    const overlap = max_distance - distance;

    return if (overlap <= 0.0) null else .{
        .{ // for `a`
            .layers = layers,
            .normal = a_center.subtract(b_center).normalizeSafe() orelse .{ .x = 1.0 },
            .depth = overlap,
        },
        .{ // for `b`
            .layers = layers,
            .normal = b_center.subtract(a_center).normalizeSafe() orelse .{ .x = -1.0 },
            .depth = overlap,
        },
    };
}

/// Asserts `c.collider == .circle` and `r.collider == .rectangle`.
fn circleRectangleCollision(c: GameObject, r: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const c_circle = c.collider.circle;
    const r_rectangle = r.collider.rectangle;

    const c_center = c_circle.position.multiply(c.transform.scale).rotate(c.transform.rotation).add(c.transform.position);
    const c_radius = c_circle.scale.x * c.transform.scale.x / 2.0;
    const r_center = r_rectangle.position.multiply(r.transform.scale).rotate(r.transform.rotation).add(r.transform.position);
    const r_size = r_rectangle.scale.multiply(r.transform.scale);
    assert(r_size.x >= 0.0 and r_size.y >= 0.0);

    const closest_to_c: Vec2 = blk: {
        var x: f32 = undefined;
        if (c_center.x < r_center.x - r_size.x / 2.0) {
            x = r_center.x - r_size.x / 2.0;
        } else if (c_center.x > r_center.x + r_size.x / 2.0) {
            x = r_center.x + r_size.x / 2.0;
        } else {
            x = c_center.x;
        }

        var y: f32 = undefined;
        if (c_center.y < r_center.y - r_size.y / 2.0) {
            y = r_center.y - r_size.y / 2.0;
        } else if (c_center.y > r_center.y + r_size.y / 2.0) {
            y = r_center.y + r_size.y / 2.0;
        } else {
            y = c_center.y;
        }

        break :blk .{ .x = x, .y = y };
    };

    const distance = closest_to_c.subtract(c_center).len();
    const max_distance = c_radius;
    const overlap = max_distance - distance;

    return if (overlap <= 0.0) null else return .{
        .{ // for `c`
            .layers = layers,
            .normal = c_center.subtract(closest_to_c).normalizeSafe() orelse .{ .x = 1.0 },
            .depth = overlap,
        },
        .{ // for `r`
            .layers = layers,
            .normal = closest_to_c.subtract(c_center).normalizeSafe() orelse .{ .x = -1.0 },
            .depth = overlap,
        },
    };
}

/// Asserts `a.collider` and `b.collider` are both `.rectangle`.
fn rectangleRectangleCollision(a: GameObject, b: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const a_rectangle = a.collider.rectangle;
    const b_rectangle = b.collider.rectangle;

    const a_center = a_rectangle.position.multiply(a.transform.scale).rotate(a.transform.rotation).add(a.transform.position);
    const b_center = b_rectangle.position.multiply(b.transform.scale).rotate(b.transform.rotation).add(b.transform.position);
    const a_size = a_rectangle.scale.multiply(a.transform.scale);
    assert(a_size.x >= 0.0 and a_size.y >= 0.0);
    const b_size = b_rectangle.scale.multiply(b.transform.scale);
    assert(b_size.x >= 0.0 and b_size.y >= 0.0);

    // Figure out if they collide based on projections

    const a_x_min = a_center.x - a_size.x / 2.0;
    const a_x_max = a_center.x + a_size.x / 2.0;
    const a_y_min = a_center.y - a_size.y / 2.0;
    const a_y_max = a_center.y + a_size.y / 2.0;
    const b_x_min = b_center.x - b_size.x / 2.0;
    const b_x_max = b_center.x + b_size.x / 2.0;
    const b_y_min = b_center.y - b_size.y / 2.0;
    const b_y_max = b_center.y + b_size.y / 2.0;

    if (a_x_min >= b_x_max) return null;
    if (a_x_max <= b_x_min) return null;
    if (a_y_min >= b_y_max) return null;
    if (a_y_max <= b_y_min) return null;

    // From here on out, we know `a` and `b` collide.
    // Now we just gotta figure out the normal and depth..

    const a_normal: Vec2 = blk: {
        if (a_center.x >= b_x_min and a_center.x <= b_x_max) {
            break :blk .{ .x = 0.0, .y = noZeroSign(a_center.y - b_center.y) };
        } else if (a_center.y >= b_y_min and a_center.y <= b_y_max) {
            break :blk .{ .x = noZeroSign(a_center.x - b_center.x), .y = 0.0 };
        }

        if (a_center.x < b_x_min) {
            if (a_center.y < b_y_min) {
                const diff: Vec2 = .{
                    .x = a_center.x - b_x_min,
                    .y = a_center.y - b_y_min,
                };
                assert(diff.x < 0 and diff.y < 0);
                if (-diff.x >= -diff.y) {
                    break :blk .{ .x = -1.0, .y = 0.0 };
                } else {
                    break :blk .{ .x = 0.0, .y = -1.0 };
                }
            } else { // a_center.y > b_y_max
                const diff: Vec2 = .{
                    .x = a_center.x - b_x_min,
                    .y = a_center.y - b_y_max,
                };
                assert(diff.x < 0 and diff.y > 0);
                if (-diff.x >= diff.y) {
                    break :blk .{ .x = -1.0, .y = 0.0 };
                } else {
                    break :blk .{ .x = 0.0, .y = 1.0 };
                }
            }
        } else { // a_center.x > b_x_max
            if (a_center.y < b_y_min) {
                const diff: Vec2 = .{
                    .x = a_center.x - b_x_max,
                    .y = a_center.y - b_y_min,
                };
                assert(diff.x > 0 and diff.y < 0);
                if (diff.x >= -diff.y) {
                    break :blk .{ .x = 1.0, .y = 0.0 };
                } else {
                    break :blk .{ .x = 0.0, .y = -1.0 };
                }
            } else { // a_center.y > b_y_max
                const diff: Vec2 = .{
                    .x = a_center.x - b_x_max,
                    .y = a_center.y - b_y_max,
                };
                assert(diff.x > 0 and diff.y > 0);
                if (diff.x >= diff.y) {
                    break :blk .{ .x = 1.0, .y = 0.0 };
                } else {
                    break :blk .{ .x = 0.0, .y = 1.0 };
                }
            }
        }
    };
    const b_normal = a_normal.scale(-1.0);

    const depth: f32 = blk: {
        if (a_normal.x < 0.0) {
            break :blk a_x_max - b_x_min;
        } else if (a_normal.x > 0.0) {
            break :blk b_x_max - a_x_min;
        } else if (a_normal.y < 0.0) {
            break :blk a_y_max - b_y_min;
        } else { // a_normal.y > 0.0
            break :blk b_y_max - a_y_min;
        }
    };

    return .{
        .{ // for `a`
            .layers = layers,
            .normal = a_normal,
            .depth = depth,
        },
        .{ // for `b`
            .layers = layers,
            .normal = b_normal,
            .depth = depth,
        },
    };
}

/// Asserts `c.collider == .circle` and `r.collider == .rounded_rectangle`.
fn circleRoundedCollision(c: GameObject, r: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const c_circle = c.collider.circle;
    const r_rounded = r.collider.rounded_rectangle;

    _ = .{ c_circle, r_rounded, layers };
    log.warn("circle-rounded collisions not yet implemented", .{});

    return null;
}

/// Asserts `a.collider == .rectangle` and `b.collider == .rounded_rectangle`.
fn rectangleRoundedCollision(a: GameObject, b: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const a_rectangle = a.collider.rectangle;
    const b_rounded = b.collider.rounded_rectangle;

    _ = .{ a_rectangle, b_rounded, layers };
    log.warn("rectangle-rounded collisions not yet implemented", .{});

    return null;
}

/// Asserts `a.collider` and `b.collider` are both `.rounded_rectangle`.
fn roundedRoundedCollision(a: GameObject, b: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const a_rounded = a.collider.rounded_rectangle;
    const b_rounded = b.collider.rounded_rectangle;

    _ = .{ a_rounded, b_rounded, layers };
    log.warn("rounded-rounded collisions not yet implemented", .{});

    return null;
}

/// Returns sign of `f`, but replaces `0.0` with `1.0`.
fn noZeroSign(f: f32) f32 {
    return if (f < 0) -1.0 else 1.0;
}
