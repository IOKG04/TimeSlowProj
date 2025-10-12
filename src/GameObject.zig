//! A generic game object, to be intrusively
//! added to anything that can appear in the game.
//!
//! Call order per frame:
//! 1. update
//! 2. onCollision (for each collision)

const std = @import("std");
const raylib = @import("raylib");

const scene = @import("scene.zig");
const Vec2 = @import("Vec2.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const GameObject = @This();

transform: Transform = .{},

paused: bool = false,
update: *const fn (self: *GameObject, gpa: Allocator, dt: f32) UpdateError!void,
deinit: *const fn (self: *GameObject, gpa: Allocator) void,

draw: DrawObject = .none,
draw_order: DrawOrder = .default,

collider: Collider = .none,
collision_layer: CollisionLayer = .{},
onCollision: *const fn (self: *GameObject, other: *const GameObject, collision_info: CollisionInfo, gpa: Allocator) UpdateError!void = noOnCollision,

metadata: Metadata = .{},

pub const Transform = struct {
    position: Vec2 = .zero,
    rotation: f32 = 0.0,
    scale: Vec2 = .one,
    pub fn toSimple(t: Transform) SimpleTransform {
        return .{
            .position = t.position,
            .scale = t.scale,
        };
    }
};
pub const SimpleTransform = struct {
    position: Vec2 = .zero,
    scale: Vec2 = .one,
    pub fn toTransform(st: SimpleTransform) Transform {
        return .{
            .position = st.position,
            .scale = st.scale,
        };
    }
};
pub const DrawObject = union (enum) {
    none: void,
    texture: *const raylib.Texture2D,
    texture_offset: struct {
        texture: *const raylib.Texture2D,
        offset: Vec2,
    },
    circle: raylib.Color,
    circle_dbg: raylib.Color,
    rectangle: raylib.Color,
};
pub const DrawOrder = enum {
    invisible,
    background,
    default,
    foreground,
};
pub const Collider = union (enum) {
    none: void,
    /// Transform contains offset and size multiplier from containing GameObject.
    circle: SimpleTransform,
    /// Transform contains offset and size multiplier from containing GameObject.
    rectangle: SimpleTransform,

    // TODO: `rounded_rectangle`.
};
pub const CollisionLayer = packed struct {
    movement: bool = false,
    projectiles: bool = false,

    pub const BackingInteger = @typeInfo(CollisionLayer).@"struct".backing_integer.?;

    /// Returns layers `a` and `b` can collide on
    /// or `null` if they cannot collide.
    pub fn collidingLayers(a: CollisionLayer, b: CollisionLayer) ?CollisionLayer {
        const a_int: BackingInteger = @bitCast(a);
        const b_int: BackingInteger = @bitCast(b);
        return @bitCast(a_int & b_int);
    }
    /// Possibly make this `inline`.
    pub fn isNone(cl: CollisionLayer) bool {
        const cl_int: BackingInteger = @bitCast(cl);
        return cl_int == 0;
    }
};
pub const CollisionInfo = struct {
    layers: CollisionLayer,
    /// Points away from `other`'s surface.
    normal: Vec2,
    /// If `self` was moved this much in the direction of
    /// `collision_normal`, the collision wouldn't've happened.
    depth: f32,
};
pub const Metadata = struct {
    movability: enum {
        /// Never moved.
        wall,
        /// Isn't moved by outside forces.
        immovable,
        /// Is moved by outside forces.
        normal,
        /// Doesn't apply moving forces.
        bullet,
    } = .normal,
};
pub const UpdateError = error {
    Generic,
    LoadTexture,
} || Allocator.Error;

/// The default collision function.
/// Should never get called, replace this
/// if the game object can collide.
pub fn noOnCollision(self: *GameObject, other: *const GameObject, collision_info: CollisionInfo, gpa: Allocator) UpdateError!void {
    _ = self;
    _ = other;
    _ = collision_info;
    _ = gpa;
    unreachable;
}
/// Functions that do nothing.
pub const noop = struct {
    pub fn update(go: *GameObject, gpa: Allocator, dt: f32) UpdateError!void {
        _ = .{ go, gpa, dt };
    }
    pub fn onCollision(self: *GameObject, other: *const GameObject, collision_info: CollisionInfo, gpa: Allocator) UpdateError!void {
        _ = .{ self, other, collision_info, gpa };
    }
};
/// Useful functions.
pub const useful = struct {
    pub const on_collision = struct {
        /// Resolves collisions in a "physics" based manner.
        /// Asserts `self.metadata.movability == .normal`.
        pub fn physics(self: *GameObject, other: *const GameObject, collision_info: CollisionInfo, gpa: Allocator) UpdateError!void {
            assert(self.metadata.movability == .normal);
            _ = gpa;

            const movement_factor: f32 = switch (other.metadata.movability) {
                .bullet => 0.0,
                .normal => collision_info.depth / 2.0,
                .immovable, .wall => collision_info.depth,
            };
            self.transform.position = self.transform.position.add(collision_info.normal.scale(movement_factor));
        }
        /// Destroys `self`.
        pub fn selfDestruct(self: *GameObject, other: *const GameObject, collision_info: CollisionInfo, gpa: Allocator) UpdateError!void {
            _ = .{ other, collision_info, gpa };
            scene.removeGameObject(self);
        }
    };
};
