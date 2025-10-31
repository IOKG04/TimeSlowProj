const std = @import("std");
const raylib = @import("raylib");
const Vec2 = @import("Vec2");
const options = @import("options");

const GameObject = @import("../../GameObject.zig");
const scene = @import("../../scene.zig");

const Allocator = std.mem.Allocator;

const PushableText = @This();

const font_size = 0.5;
const font_spacing = 0.0;

game_object: GameObject,
size: Vec2,
text: [:0]const u8,
font: raylib.Font,

pub fn init(gpa: Allocator, text: [:0]const u8, font: raylib.Font, position: Vec2) GameObject.UpdateError!*PushableText {
    const outp = try gpa.create(PushableText);
    errdefer gpa.destroy(outp);

    const text_size: Vec2 = .fromRaylib(raylib.measureTextEx(
        font,
        text,
        font_size,
        font_spacing,
    ));

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
            },

            .update = GameObject.noop.update,
            .deinit = deinit,

            .draw = .{ .custom = draw },

            .collider = .{
                .rectangle = .{
                    .scale = text_size,
                },
            },
            .collision_layer = .{
                .movement = true,
                .background = true,
            },
            .onCollision = GameObject.useful.on_collision.physics,

            .metadata = .{
                .movability = .normal,
            },
        },
        .size = text_size,
        .text = text,
        .font = font,
    };

    try scene.addGameObject(gpa, &outp.game_object);
    errdefer scene.removeGameObject(&outp.game_object);

    return outp;
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const pushable_text: *PushableText = @fieldParentPtr("game_object", go);
    gpa.destroy(pushable_text);
}

fn draw(go: *GameObject) GameObject.DrawObject {
    const pushable_text: *PushableText = @fieldParentPtr("game_object", go);

    const offset = pushable_text.size.scale(0.5).scale(pushable_text.game_object.transform.scale.x);
    const text_position = pushable_text.game_object.transform.position.subtract(offset);

    raylib.drawTextEx(
        pushable_text.font,
        pushable_text.text,
        text_position.toRaylib(),
        font_size * pushable_text.game_object.transform.scale.x,
        font_spacing,
        .purple,
    );

    //return .{ .circle = .init(0xff, 0xff, 0xff, 0x80) };
    return .none;
}
