const std = @import("std");
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
