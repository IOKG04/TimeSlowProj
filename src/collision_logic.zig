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

    const a_center = a_circle.position.multiply(a.transform.scale).add(a.transform.position);
    const b_center = b_circle.position.multiply(b.transform.scale).add(b.transform.position);
    const distance = a_center.subtract(b_center).len();

    const a_radius = a_circle.scale.x * a.transform.scale.x / 2.0;
    const b_radius = b_circle.scale.x * b.transform.scale.x / 2.0;
    const max_distance = a_radius + b_radius;

    const overlap = max_distance - distance;

    return if (overlap <= 0.0) null else .{
        .{ // for `a`
            .layers = layers,
            .normal = a_center.subtract(b_center).normalizeSafe() orelse .unit_x,
            .depth = overlap,
        },
        .{ // for `b`
            .layers = layers,
            .normal = b_center.subtract(a_center).normalizeSafe() orelse .unit_x,
            .depth = overlap,
        },
    };
}

/// Asserts `c.collider == .circle` and `r.collider == .rectangle`.
fn circleRectangleCollision(c: GameObject, r: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const c_circle = c.collider.circle;
    const r_rectangle = r.collider.rectangle;

    const c_center = c_circle.position.multiply(c.transform.scale).add(c.transform.position);
    const c_radius = c_circle.scale.x * c.transform.scale.x / 2.0;
    const r_center = r_rectangle.position.multiply(r.transform.scale).add(r.transform.position);
    const r_size = r_rectangle.scale.multiply(r.transform.scale);
    const r_angle = r_rectangle.rotation + r.transform.rotation;

    const r_center_rotated = r_center.rotateAround(c_center, -r_angle);

    const closest_to_c_rotated: Vec2 = blk: {
        var x: f32 = undefined;
        if (c_center.x < r_center_rotated.x - r_size.x / 2.0) {
            x = r_center_rotated.x - r_size.x / 2.0;
        } else if (c_center.x > r_center_rotated.x + r_size.x / 2.0) {
            x = r_center_rotated.x + r_size.x / 2.0;
        } else {
            x = c_center.x;
        }

        var y: f32 = undefined;
        if (c_center.y < r_center_rotated.y - r_size.y / 2.0) {
            y = r_center_rotated.y - r_size.y / 2.0;
        } else if (c_center.y > r_center_rotated.y + r_size.y / 2.0) {
            y = r_center_rotated.y + r_size.y / 2.0;
        } else {
            y = c_center.y;
        }

        break :blk .{ .x = x, .y = y };
    };
    const closest_to_c = closest_to_c_rotated.rotateAround(c_center, r_angle);

    const distance = closest_to_c.subtract(c_center).len();
    const max_distance = c_radius;
    const overlap = max_distance - distance;

    return if (overlap <= 0.0) null else return .{
        .{ // for `c`
            .layers = layers,
            .normal = c_center.subtract(closest_to_c).normalizeSafe() orelse .unit_x,
            .depth = overlap,
        },
        .{ // for `r`
            .layers = layers,
            .normal = closest_to_c.subtract(c_center).normalizeSafe() orelse .unit_x,
            .depth = overlap,
        },
    };
}


/// Asserts `a.collider` and `b.collider` are both `.rectangle`.
fn rectangleRectangleCollision(a: GameObject, b: GameObject, layers: CollisionLayer) ?[2]CollisionInfo {
    const a_rectangle = a.collider.rectangle;
    const b_rectangle = b.collider.rectangle;

    const a_center = a_rectangle.position.multiply(a.transform.scale).add(a.transform.position);
    const b_center = b_rectangle.position.multiply(b.transform.scale).add(b.transform.position);
    const a_size = a_rectangle.scale.multiply(a.transform.scale);
    const b_size = b_rectangle.scale.multiply(b.transform.scale);
    const a_angle = a_rectangle.rotation + a.transform.rotation;
    const b_angle = b_rectangle.rotation + b.transform.rotation;

    const a_tr = a_center.add(a_size.multiply(.{ .x = 0.5, .y = 0.5 }).rotate(a_angle));
    const a_br = a_center.add(a_size.multiply(.{ .x = 0.5, .y = -0.5 }).rotate(a_angle));
    const a_tl = a_center.add(a_size.multiply(.{ .x = -0.5, .y = 0.5 }).rotate(a_angle));
    const a_bl = a_center.add(a_size.multiply(.{ .x = -0.5, .y = -0.5 }).rotate(a_angle));
    const b_tr = b_center.add(b_size.multiply(.{ .x = 0.5, .y = 0.5 }).rotate(b_angle));
    const b_br = b_center.add(b_size.multiply(.{ .x = 0.5, .y = -0.5 }).rotate(b_angle));
    const b_tl = b_center.add(b_size.multiply(.{ .x = -0.5, .y = 0.5 }).rotate(b_angle));
    const b_bl = b_center.add(b_size.multiply(.{ .x = -0.5, .y = -0.5 }).rotate(b_angle));

    // Figure out if they collide based on projections

    // Projecting `b` onto `a`s axes.
    for ([2]f32{ a_angle, a_angle + 0.5 * pi }, 0..) |projection_angle, i| {
        const projection_vector: Vec2 = .fromAngle(projection_angle);

        var b_projected_min = math.inf(f32);
        var b_projected_max = -math.inf(f32);
        for ([_]Vec2{ b_tr, b_br, b_tl, b_bl }) |corner| {
            const corner_projected = corner.projectOntoNormalized(projection_vector);
            b_projected_min = @min(b_projected_min, corner_projected);
            b_projected_max = @max(b_projected_max, corner_projected);
        }

        const a_projected_center = a_center.projectOntoNormalized(projection_vector);
        const a_projected_size = switch (i) {
            0 => a_size.x / 2.0, // horizontal
            1 => a_size.y / 2.0, // vertical
            else => unreachable,
        };
        const a_projected_min = a_projected_center - a_projected_size;
        const a_projected_max = a_projected_center + a_projected_size;

        if (b_projected_max <= a_projected_min or b_projected_min >= a_projected_max) return null;
    }

    // Projecting `a` onto `b`s axes.
    for ([2]f32{ b_angle, b_angle + 0.5 * pi }, 0..) |projection_angle, i| {
        const projection_vector: Vec2 = .fromAngle(projection_angle);

        var a_projected_min = math.inf(f32);
        var a_projected_max = -math.inf(f32);
        for ([_]Vec2{ a_tr, a_br, a_tl, a_bl }) |corner| {
            const corner_projected = corner.projectOntoNormalized(projection_vector);
            a_projected_min = @min(a_projected_min, corner_projected);
            a_projected_max = @max(a_projected_max, corner_projected);
        }

        const b_projected_center = b_center.projectOntoNormalized(projection_vector);
        const b_projected_size = switch (i) {
            0 => b_size.x / 2.0, // horizontal
            1 => b_size.y / 2.0, // vertical
            else => unreachable,
        };
        const b_projected_min = b_projected_center - b_projected_size;
        const b_projected_max = b_projected_center + b_projected_size;

        if (a_projected_max <= b_projected_min or a_projected_min >= b_projected_max) return null;
    }

    // From here on out, we know `a` and `b` collide.
    // Now we just gotta figure out the normal and depth..

    const a_normal_angle: f32 = blk: {
        const a_center_rotated = a_center.rotateAround(b_center, b_angle);
        const difference = a_center_rotated.subtract(b_center);
        const difference_scaled = difference.divide(b_size);
        const angle_rotated: f32 = if (@abs(difference_scaled.x) >= @abs(difference_scaled.y)) ar_blk: {
            break :ar_blk if (difference_scaled.x >= 0.0) 0.0 * pi else 1.0 * pi;
        } else ar_blk: {
            break :ar_blk if (difference_scaled.y >= 0.0) 0.5 * pi else 1.5 * pi;
        };
        break :blk angle_rotated - b_angle;
    };
    const a_normal: Vec2 = .fromAngle(a_normal_angle);

    const b_normal_angle: f32 = blk: {
        const b_center_rotated = b_center.rotateAround(a_center, a_angle);
        const difference = b_center_rotated.subtract(a_center);
        const difference_scaled = difference.divide(a_size);
        const angle_rotated: f32 = if (@abs(difference_scaled.x) >= @abs(difference_scaled.y)) ar_blk: {
            break :ar_blk if (difference_scaled.x >= 0.0) 0.0 * pi else 1.0 * pi;
        } else ar_blk: {
            break :ar_blk if (difference_scaled.y >= 0.0) 0.5 * pi else 1.5 * pi;
        };
        break :blk angle_rotated - a_angle;
    };
    const b_normal: Vec2 = .fromAngle(b_normal_angle);

    const a_depth: f32 = blk: {
        // Rotate everything such that `a_normal` would be `.{ .x = 1.0, .y = 0.0 }`.
        const a_tr_rotated = a_tr.rotate(-a_normal_angle);
        const a_tl_rotated = a_tl.rotate(-a_normal_angle);
        const a_br_rotated = a_br.rotate(-a_normal_angle);
        const a_bl_rotated = a_bl.rotate(-a_normal_angle);
        const b_tr_rotated = b_tr.rotate(-a_normal_angle);
        const b_bl_rotated = b_bl.rotate(-a_normal_angle);

        const y_min = @min(b_tr_rotated.y, b_bl_rotated.y);
        const y_max = @max(b_tr_rotated.y, b_bl_rotated.y);
        const depth_0 = @max(b_tr_rotated.x, b_bl_rotated.x);

        var leftmost: [4]Vec2 = .{ a_tr_rotated, a_tl_rotated, a_br_rotated, a_bl_rotated };
        if (leftmost[3].x < leftmost[2].x) mem.swap(Vec2, &leftmost[3], &leftmost[2]); // pass 1 (bubble sort)
        if (leftmost[2].x < leftmost[1].x) mem.swap(Vec2, &leftmost[2], &leftmost[1]);
        if (leftmost[1].x < leftmost[0].x) mem.swap(Vec2, &leftmost[1], &leftmost[0]);
        if (leftmost[3].x < leftmost[2].x) mem.swap(Vec2, &leftmost[3], &leftmost[2]); // pass 2
        if (leftmost[2].x < leftmost[1].x) mem.swap(Vec2, &leftmost[2], &leftmost[1]);
        if (leftmost[3].x < leftmost[2].x) mem.swap(Vec2, &leftmost[3], &leftmost[2]); // pass 3

        // `pl_0` is leftmost point, `pl_1` is leftmost point not on the same side as `pl_0`.
        const pl_0 = leftmost[0];
        if (pl_0.y >= y_min and pl_0.y <= y_max) break :blk depth_0 - pl_0.x;
        const pl_1 = if (pl_0.y < y_min) if (leftmost[1].y >= y_min) leftmost[1] else leftmost[2] else if (leftmost[1].y <= y_max) leftmost[1] else leftmost[2];

        // Find `m` and `n` such that `x = my + n` describes the line between `pl_0` and `pl_1`,
        // then put in the closest point to `pl_0` within bounds as `y` and get `x`.
        const pl_difference = pl_0.subtract(pl_1);
        const m = pl_difference.x / pl_difference.y;
        const n = pl_1.x - m * pl_1.y;
        const y = if (pl_0.y < y_min) y_min else y_max;
        const x = m * y + n;
        break :blk depth_0 - x;
    };
    const b_depth: f32 = blk: {
        // Rotate everything such that `b_normal` would be `.{ .x = 1.0, .y = 0.0 }`.
        const b_tr_rotated = b_tr.rotate(-b_normal_angle);
        const b_tl_rotated = b_tl.rotate(-b_normal_angle);
        const b_br_rotated = b_br.rotate(-b_normal_angle);
        const b_bl_rotated = b_bl.rotate(-b_normal_angle);
        const a_tr_rotated = a_tr.rotate(-b_normal_angle);
        const a_bl_rotated = a_bl.rotate(-b_normal_angle);

        const y_min = @min(a_tr_rotated.y, a_bl_rotated.y);
        const y_max = @max(a_tr_rotated.y, a_bl_rotated.y);
        const depth_0 = @max(a_tr_rotated.x, a_bl_rotated.x);

        var leftmost: [4]Vec2 = .{ b_tr_rotated, b_tl_rotated, b_br_rotated, b_bl_rotated };
        if (leftmost[3].x < leftmost[2].x) mem.swap(Vec2, &leftmost[3], &leftmost[2]); // pass 1 (bubble sort)
        if (leftmost[2].x < leftmost[1].x) mem.swap(Vec2, &leftmost[2], &leftmost[1]);
        if (leftmost[1].x < leftmost[0].x) mem.swap(Vec2, &leftmost[1], &leftmost[0]);
        if (leftmost[3].x < leftmost[2].x) mem.swap(Vec2, &leftmost[3], &leftmost[2]); // pass 2
        if (leftmost[2].x < leftmost[1].x) mem.swap(Vec2, &leftmost[2], &leftmost[1]);
        if (leftmost[3].x < leftmost[2].x) mem.swap(Vec2, &leftmost[3], &leftmost[2]); // pass 3

        // `pl_0` is leftmost point, `pl_1` is leftmost point not on the same side as `pl_0`.
        const pl_0 = leftmost[0];
        if (pl_0.y >= y_min and pl_0.y <= y_max) break :blk depth_0 - pl_0.x;
        const pl_1 = if (pl_0.y < y_min) if (leftmost[1].y >= y_min) leftmost[1] else leftmost[2] else if (leftmost[1].y <= y_max) leftmost[1] else leftmost[2];

        // Find `m` and `n` such that `x = my + n` describes the line between `pl_0` and `pl_1`,
        // then put in the closest point to `pl_0` within bounds as `y` and get `x`.
        const pl_difference = pl_0.subtract(pl_1);
        const m = pl_difference.x / pl_difference.y;
        const n = pl_1.x - m * pl_1.y;
        const y = if (pl_0.y < y_min) y_min else y_max;
        const x = m * y + n;
        break :blk depth_0 - x;
    };

    return .{
        .{ // for `a`
            .layers = layers,
            .normal = a_normal,
            .depth = a_depth,
        },
        .{ // for `b`
            .layers = layers,
            .normal = b_normal,
            .depth = b_depth,
        },
    };
}

/// Returns sign of `f`, but replaces `0.0` with `1.0`.
fn noZeroSign(f: f32) f32 {
    return if (f < 0) -1.0 else 1.0;
}
