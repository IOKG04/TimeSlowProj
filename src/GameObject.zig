//! A generic game object, to be intrusively
//! added to anything that can appear in the game.
//!
//! Call order per frame:
//! 1. update
//! 2. onCollision (for each collision)

const std = @import("std");
const raylib = @import("raylib");
const Vec2 = @import("Vec2");
const Collision = @import("Collision");

const scene = @import("scene.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const GameObject = @This();

transform: Transform = .{},

paused: bool = false,
update: *const fn (self: *GameObject, gpa: Allocator, dt: f32) UpdateError!void,
deinit: *const fn (self: *GameObject, gpa: Allocator) void,

draw: DrawObject = .none,
draw_order: DrawOrder = .default,

collider: Collision.Collider = .none,
collision_layer: Collision.Layer = .{},
onCollision: *const fn (self: *GameObject, other: *const GameObject, collision_info: Collision, gpa: Allocator) UpdateError!void = no.onCollision,

metadata: Metadata = .{},

pub const Transform = struct {
    position: Vec2 = .zero,
    rotation: f32 = 0.0,
    scale: Vec2 = .one,
};
pub const DrawObject = union (enum) {
    none: void,
    texture: *const raylib.Texture2D,
    texture_transformed: struct {
        texture: *const raylib.Texture2D,
        transform: Transform = .{},
        flipped: struct {
            horizontal: bool = false,
            vertical: bool = false,
        } = .{},
    },
    circle: raylib.Color,
    circle_dbg: raylib.Color,
    rectangle: raylib.Color,
};
pub const DrawOrder = enum {
    invisible,
    background,
    default,
    // TODO: Possibly add `gun` here.
    foreground,

    pub const draw_order: [3]DrawOrder = .{
        .background,
        .default,
        .foreground,
    };
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
    /// Should only be `true` for game objects created from a level background.
    is_background: bool = false,
};
pub const UpdateError = error {
    Generic,
    LoadTexture,
} || Allocator.Error;

/// The functions should never be called.
pub const no = struct {
    pub fn update(go: *GameObject, gpa: Allocator, dt: f32) UpdateError!void {
        _ = .{ go, gpa, dt };
        unreachable;
    }
    pub fn deinit(go: *GameObject, gpa: Allocator) void {
        _ = .{ go, gpa };
        unreachable;
    }
    pub fn onCollision(self: *GameObject, other: *const GameObject, collision_info: Collision, gpa: Allocator) UpdateError!void {
        _ = .{ self, other, collision_info, gpa };
        unreachable;
    }
};
/// Functions that do nothing.
pub const noop = struct {
    pub fn update(go: *GameObject, gpa: Allocator, dt: f32) UpdateError!void {
        _ = .{ go, gpa, dt };
    }
    pub fn onCollision(self: *GameObject, other: *const GameObject, collision_info: Collision, gpa: Allocator) UpdateError!void {
        _ = .{ self, other, collision_info, gpa };
    }
};
/// Useful functions.
pub const useful = struct {
    pub const on_collision = struct {
        /// Resolves collisions in a "physics" based manner.
        /// Asserts `self.metadata.movability == .normal`.
        pub fn physics(self: *GameObject, other: *const GameObject, collision_info: Collision, gpa: Allocator) UpdateError!void {
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
        pub fn selfDestruct(self: *GameObject, other: *const GameObject, collision_info: Collision, gpa: Allocator) UpdateError!void {
            _ = .{ other, collision_info, gpa };
            scene.removeGameObject(self);
        }
    };
};
