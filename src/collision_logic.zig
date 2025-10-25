//! Uses optimized float mode.

const std = @import("std");
const math = std.math;
const mem = std.mem;
const Vec2 = @import("Vec2");
const Collision = @import("Collision");

const GameObject = @import("GameObject.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const pi = math.pi;

const log = @import("main.zig").log;

comptime { @setFloatMode(.optimized); }

pub const LayeredCollider = struct {
    collider: Collision.Collider,
    layer: Collision.Layer,

    /// Returns `null` if the result wouldn't
    /// be able to collide.
    pub fn fromGameObject(go: GameObject) ?LayeredCollider {
        if (go.collision_layer.isNone() or go.collider == .none) return null;
        return .{
            .layer = go.collision_layer,
            .collider = switch (go.collider) {
                .circle => |c| .{ .circle = .{
                    .position = c.position.multiply(go.transform.scale).rotate(go.transform.rotation).add(go.transform.position),
                    .radius = c.radius * go.transform.scale.x,
                } },
                .rectangle => |r| .{ .rectangle = .{
                    .position = r.position.multiply(go.transform.scale).rotate(go.transform.rotation).add(go.transform.position),
                    .scale = r.scale.multiply(go.transform.scale),
                } },
                .rounded_rectangle => |rr| .{ .rounded_rectangle = .{
                    .position = rr.position.multiply(go.transform.scale).rotate(go.transform.rotation).add(go.transform.position),
                    .scale = rr.scale.subtract(.{ .x = 2.0 * rr.radius, .y = 2.0 * rr.radius }).multiply(go.transform.scale).add(.{ .x = 2.0 * rr.radius, .y = 2.0 * rr.radius }),
                    .radius = rr.radius,
                } },
                .none => unreachable,
            },
        };
    }
};

/// If the objects are colliding, returns
/// the collision info for `self` and `other`.
/// Otherwise returns `null`.
///
/// Asserts both objects have colliders.
pub fn getCollisions(self: LayeredCollider, other: LayeredCollider) ?[2]Collision {
    assert(self.collider != .none);
    assert(other.collider != .none);

    const layers = self.layer.collidingLayers(other.layer) orelse return null;

    switch (self.collider) {
        .circle => |c_self| switch (other.collider) {
            .circle => |c_other| return circleCircleCollision(c_self, c_other, layers),
            .rectangle => |c_other| return circleRectangleCollision(c_self, c_other, layers),
            .rounded_rectangle => |c_other|  return circleRoundedCollision(c_self, c_other, layers),
            .none => unreachable,
        },
        .rectangle => |c_self| switch (other.collider) {
            .circle => |c_other| { // switch order
                const cr_collision = circleRectangleCollision(c_other, c_self, layers) orelse return null;
                return .{ cr_collision[1], cr_collision[0] };
            },
            .rectangle => |c_other| return rectangleRectangleCollision(c_self, c_other, layers),
            .rounded_rectangle => |c_other| return rectangleRoundedCollision(c_self, c_other, layers),
            .none => unreachable,
        },
        .rounded_rectangle => |c_self| switch (other.collider) {
            .circle => |c_other| { // switch order
                const cr_collision = circleRoundedCollision(c_other, c_self, layers) orelse return null;
                return .{ cr_collision[1], cr_collision[0] };
            },
            .rectangle => |c_other| { // switch order
                const rr_collision = rectangleRoundedCollision(c_other, c_self, layers) orelse return null;
                return .{ rr_collision[1], rr_collision[0] };
            },
            .rounded_rectangle => |c_other| return roundedRoundedCollision(c_self, c_other, layers),
            .none => unreachable,
        },
        .none => unreachable,
    }
}

fn circleCircleCollision(a: Collision.Collider.Circle, b: Collision.Collider.Circle, layers: Collision.Layer) ?[2]Collision {
    assert(b.radius >= 0.0);
    assert(a.radius >= 0.0);

    const difference = a.position.subtract(b.position);
    const distance = difference.len();
    const max_distance = a.radius + b.radius;

    const overlap = max_distance - distance;

    return if (overlap <= 0.0) null else .{
        .{ // for `a`
            .layers = layers,
            .normal = difference.normalizeSafe() orelse .{ .x = 1.0 },
            .depth = overlap,
        },
        .{ // for `b`
            .layers = layers,
            .normal = difference.scale(-1.0).normalizeSafe() orelse .{ .x = -1.0 },
            .depth = overlap,
        },
    };
}

fn circleRectangleCollision(c: Collision.Collider.Circle, r: Collision.Collider.Rectangle, layers: Collision.Layer) ?[2]Collision {
    assert(c.radius >= 0.0);
    assert(r.scale.x >= 0.0 and r.scale.y >= 0.0);

    const closest_to_c: Vec2 = .{
        .x = math.clamp(c.position.x, r.position.x - r.scale.x / 2.0, r.position.x + r.scale.x / 2.0),
        .y = math.clamp(c.position.y, r.position.y - r.scale.y / 2.0, r.position.y + r.scale.y / 2.0),
    };

    const difference = closest_to_c.subtract(c.position);
    const distance = difference.len();
    const overlap = c.radius - distance;

    return if (overlap <= 0.0) null else return .{
        .{ // for `c`
            .layers = layers,
            .normal = difference.scale(-1.0).normalizeSafe() orelse .{ .x = -1.0 },
            .depth = overlap,
        },
        .{ // for `r`
            .layers = layers,
            .normal = difference.normalizeSafe() orelse .{ .x = 1.0 },
            .depth = overlap,
        },
    };
}

fn rectangleRectangleCollision(a: Collision.Collider.Rectangle, b: Collision.Collider.Rectangle, layers: Collision.Layer) ?[2]Collision {
    assert(a.scale.x >= 0.0 and a.scale.y >= 0.0);
    assert(b.scale.x >= 0.0 and b.scale.y >= 0.0);

    // Figure out if they collide based on projections

    const a_x_min = a.position.x - a.scale.x / 2.0;
    const a_x_max = a.position.x + a.scale.x / 2.0;
    const a_y_min = a.position.y - a.scale.y / 2.0;
    const a_y_max = a.position.y + a.scale.y / 2.0;
    const b_x_min = b.position.x - b.scale.x / 2.0;
    const b_x_max = b.position.x + b.scale.x / 2.0;
    const b_y_min = b.position.y - b.scale.y / 2.0;
    const b_y_max = b.position.y + b.scale.y / 2.0;

    if (a_x_min >= b_x_max) return null;
    if (a_x_max <= b_x_min) return null;
    if (a_y_min >= b_y_max) return null;
    if (a_y_max <= b_y_min) return null;

    // From here on out, we know `a` and `b` collide.
    // Now we just gotta figure out the normal and depth..

    const a_normal: Vec2 = blk: {
        if (a.position.x >= b_x_min and a.position.x <= b_x_max) {
            break :blk .{ .x = 0.0, .y = noZeroSign(a.position.y - b.position.y) };
        } else if (a.position.y >= b_y_min and a.position.y <= b_y_max) {
            break :blk .{ .x = noZeroSign(a.position.x - b.position.x), .y = 0.0 };
        }

        if (a.position.x < b_x_min) {
            if (a.position.y < b_y_min) {
                const diff: Vec2 = .{
                    .x = a.position.x - b_x_min,
                    .y = a.position.y - b_y_min,
                };
                assert(diff.x < 0 and diff.y < 0);
                if (-diff.x >= -diff.y) {
                    break :blk .{ .x = -1.0, .y = 0.0 };
                } else {
                    break :blk .{ .x = 0.0, .y = -1.0 };
                }
            } else { // a.position.y > b_y_max
                const diff: Vec2 = .{
                    .x = a.position.x - b_x_min,
                    .y = a.position.y - b_y_max,
                };
                assert(diff.x < 0 and diff.y > 0);
                if (-diff.x >= diff.y) {
                    break :blk .{ .x = -1.0, .y = 0.0 };
                } else {
                    break :blk .{ .x = 0.0, .y = 1.0 };
                }
            }
        } else { // a.position.x > b_x_max
            if (a.position.y < b_y_min) {
                const diff: Vec2 = .{
                    .x = a.position.x - b_x_max,
                    .y = a.position.y - b_y_min,
                };
                assert(diff.x > 0 and diff.y < 0);
                if (diff.x >= -diff.y) {
                    break :blk .{ .x = 1.0, .y = 0.0 };
                } else {
                    break :blk .{ .x = 0.0, .y = -1.0 };
                }
            } else { // a.position.y > b_y_max
                const diff: Vec2 = .{
                    .x = a.position.x - b_x_max,
                    .y = a.position.y - b_y_max,
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

fn circleRoundedCollision(c: Collision.Collider.Circle, r: Collision.Collider.RoundedRectangle, layers: Collision.Layer) ?[2]Collision {
    assert(r.radius >= 0.0);
    assert(c.radius >= 0.0);

    const r_size = r.scale.subtract(.{ .x = 2.0 * r.radius, .y = 2.0 * r.radius });
    assert(r_size.x >= 0.0 and r_size.y >= 0.0);

    const closest_to_c_no_radius: Vec2 = .{
        .x = math.clamp(c.position.x, r.position.x - r_size.x / 2.0, r.position.x + r_size.x / 2.0),
        .y = math.clamp(c.position.y, r.position.y - r_size.y / 2.0, r.position.y + r_size.y / 2.0),
    };

    const difference = closest_to_c_no_radius.subtract(c.position);
    const distance = difference.len();
    const max_distance = c.radius + r.radius;
    const overlap = max_distance - distance;

    if (overlap <= 0.0) return null;

    return .{
        .{ // for `c`
            .layers = layers,
            .normal = difference.scale(-1.0).normalizeSafe() orelse .{ .x = -1.0 },
            .depth = overlap,
        },
        .{ // for `r`
            .layers = layers,
            .normal = difference.normalizeSafe() orelse .{ .x = 1.0 },
            .depth = overlap,
        },
    };
}

fn rectangleRoundedCollision(a: Collision.Collider.Rectangle, b: Collision.Collider.RoundedRectangle, layers: Collision.Layer) ?[2]Collision {
    assert(b.radius >= 0.0);

    const b_size = b.scale.subtract(.{ .x = 2.0 * b.radius, .y = 2.0 * b.radius });
    assert(b_size.x >= 0.0 and b_size.y >= 0.0);

    const closest_to_a_no_radius: Vec2 = .{
        .x = math.clamp(a.position.x, b.position.x - b_size.x / 2.0, b.position.x + b_size.x / 2.0),
        .y = math.clamp(a.position.y, b.position.y - b_size.y / 2.0, b.position.y + b_size.y / 2.0),
    };

    // TODO: Maybe implement logic custom-ly.
    const b_as_circle: Collision.Collider.Circle = .{
        .position = closest_to_a_no_radius,
        .radius = b.radius,
    };
    const cr_collision = circleRectangleCollision(b_as_circle, a, layers) orelse return null;
    return .{ cr_collision[1], cr_collision[0] };
}

fn roundedRoundedCollision(a: Collision.Collider.RoundedRectangle, b: Collision.Collider.RoundedRectangle, layers: Collision.Layer) ?[2]Collision {
    assert(a.radius >= 0.0);

    const a_size = a.scale.subtract(.{ .x = 2.0 * a.radius, .y = 2.0 * a.radius });
    assert(a_size.x >= 0.0 and a_size.y >= 0.0);

    const closest_to_b: Vec2 = .{
        .x = math.clamp(b.position.x, a.position.x - a_size.x / 2.0, a.position.x + a_size.x / 2.0),
        .y = math.clamp(b.position.y, a.position.y - a_size.y / 2.0, a.position.y + a_size.y / 2.0),
    };

    // TODO: Maybe implement logic custom-ly.
    const a_as_circle: Collision.Collider.Circle = .{
        .position = closest_to_b,
        .radius = a.radius,
    };
    return circleRoundedCollision(a_as_circle, b, layers);
}

/// Returns sign of `f`, but replaces `0.0` with `1.0`.
fn noZeroSign(f: f32) f32 {
    return if (f < 0) -1.0 else 1.0;
}
