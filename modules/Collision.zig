const std = @import("std");
const math = std.math;
const raylib = @import("raylib");
const Vec2 = @import("Vec2");

layers: Layer,
/// Points away from `other`'s surface.
normal: Vec2,
/// If `self` was moved this much in the direction of
/// `normal`, the collision wouldn't've happened.
depth: f32,

pub const Collider = union (enum) {
    none: void,
    circle: Circle,
    rectangle: Rectangle,
    rounded_rectangle: RoundedRectangle,
    // TODO: `rotated_rectangle`, specifically for tables and such
    //       so they can be at an angle. It is to be assumed they
    //       never collide with themselves, as to save the pain of
    //       figuring out collision normals and such for them. In
    //       their collision function, put an `unreachable` after
    //       the check if they collide at all.

    pub const Circle = struct {
        position: Vec2 = .zero,
        radius: f32 = 0.5,
    };
    pub const Rectangle = struct {
        position: Vec2 = .zero,
        scale: Vec2 = .one,
    };
    pub const RoundedRectangle = struct {
        position: Vec2 = .zero,
        scale: Vec2 = .one,
        radius: f32 = 0.0,
    };

    /// Draws `col` using raylib's drawing functions.
    /// Asserts `col != .none`.
    pub fn draw(col: Collider) void {
        col_switch: switch (col) {
            .circle => |circle| {
                raylib.drawCircleLinesV(circle.position.toRaylib(), circle.radius, .green);
            },
            .rectangle => |rectangle| {
                const tr = rectangle.position.add(rectangle.scale.multiply(.{ .x = 0.5, .y = 0.5 }));
                const br = rectangle.position.add(rectangle.scale.multiply(.{ .x = 0.5, .y = -0.5 }));
                const tl = rectangle.position.add(rectangle.scale.multiply(.{ .x = -0.5, .y = 0.5 }));
                const bl = rectangle.position.add(rectangle.scale.multiply(.{ .x = -0.5, .y = -0.5 }));
                raylib.drawLineV(tr.toRaylib(), br.toRaylib(), .green);
                raylib.drawLineV(tr.toRaylib(), tl.toRaylib(), .green);
                raylib.drawLineV(bl.toRaylib(), br.toRaylib(), .green);
                raylib.drawLineV(bl.toRaylib(), tl.toRaylib(), .green);
            },
            .rounded_rectangle => |rounded_rectangle| {
                if (rounded_rectangle.radius == 0.0) {
                    const as_rectangle: Collider = .{ .rectangle = .{
                        .position = rounded_rectangle.position,
                        .scale = rounded_rectangle.scale,
                    } };
                    continue :col_switch as_rectangle;
                }
                const size = rounded_rectangle.scale.subtract(.{ .x = 2.0 * rounded_rectangle.radius, .y = 2.0 * rounded_rectangle.radius });
                const tr = rounded_rectangle.position.add(size.multiply(.{ .x = 0.5, .y = 0.5 }));
                const br = rounded_rectangle.position.add(size.multiply(.{ .x = 0.5, .y = -0.5 }));
                const tl = rounded_rectangle.position.add(size.multiply(.{ .x = -0.5, .y = 0.5 }));
                const bl = rounded_rectangle.position.add(size.multiply(.{ .x = -0.5, .y = -0.5 }));
                for ([4]Vec2{ tr, tl, bl, br }, [4]Vec2{ tl, bl, br, tr }, [4]f32{ 0.0, 0.5, 1.0, 1.5 }) |corner, next, corner_angle_part| {
                    raylib.drawCircleSectorLines(
                        corner.toRaylib(),
                        rounded_rectangle.radius,
                        math.pi * (corner_angle_part + 0.0) * math.deg_per_rad,
                        math.pi * (corner_angle_part + 0.5) * math.deg_per_rad,
                        4,
                        .green,
                    );
                    const corner_ext = corner.add(.fromPolar(math.pi * (corner_angle_part + 0.5), rounded_rectangle.radius));
                    const next_ext = next.add(.fromPolar(math.pi * (corner_angle_part + 0.5), rounded_rectangle.radius));
                    raylib.drawLineV(corner_ext.toRaylib(), next_ext.toRaylib(), .green);
                }
            },
            .none => unreachable,
        }
    }
};

pub const Layer = packed struct {
    movement: bool = false,
    projectiles: bool = false,

    pub const BackingInteger = @typeInfo(Layer).@"struct".backing_integer.?;

    /// Returns layers `a` and `b` can collide on
    /// or `null` if they cannot collide.
    pub fn collidingLayers(a: Layer, b: Layer) ?Layer {
        const a_int: BackingInteger = @bitCast(a);
        const b_int: BackingInteger = @bitCast(b);
        const colliding_layers: BackingInteger = a_int & b_int;
        return if (colliding_layers == 0) null else @bitCast(colliding_layers);
    }
    /// Possibly make this `inline`.
    pub fn isNone(cl: Layer) bool {
        const cl_int: BackingInteger = @bitCast(cl);
        return cl_int == 0;
    }
};
