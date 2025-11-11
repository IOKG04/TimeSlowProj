//! TODO: Fix this some day!

const std = @import("std");
const raylib = @import("raylib");
const Vec2 = @import("Vec2");
const options = @import("options");

const game = @import("game.zig");
const GameObject = @import("GameObject.zig");

const Allocator = std.mem.Allocator;
const Font = raylib.Font;

const Dialogue = @This();

/// By how much the textbox texture
/// is upscaled.
pub const tb_scale = 16;
/// Size of texture with border.
pub const tb_size: Vec2 = .scale(.{
    .x = 50,
    .y = 18,
}, tb_scale);
/// Size of writable part.
pub const tb_size_inner: Vec2 = .scale(.{
    .x = 50 - 2 - 2,
    .y = 18 - 2 - 2,
}, tb_scale);
pub const tb_vertical_margin: f32 = 2 * tb_scale;
pub const tb_origin: Vec2 = .{
    .x = @floatFromInt(options.window_w / 2),
    .y = @as(f32, @floatFromInt(options.window_h)) - tb_vertical_margin - tb_size.y / 2.0,
};
pub const tb_spacing_size_correlation = 12.0;
pub const tb_texture_name = "textbox";

owner: ?*anyopaque,
/// If a textbox is returned, that one
/// will replace the current one. If
/// `null` is returned, the dialogue ends.
callback: *const CallbackFn,

textbox: Textbox,

pub const CallbackFn = fn (dialogue: Dialogue, gpa: Allocator, choice: ?Choice) GameObject.UpdateError!?Textbox;

pub const Textbox = struct {
    text: [:0]const u8,
    font: Font,
    font_size: f32,
    font_spacing: f32,

    choice: ?Choice.Kind,

    /// Owner defined.
    id: u16,

    pub fn draw(tb: *Textbox) void {
        const text = tb.text;
        const font = tb.font;
        const font_size = tb.font_size;
        const font_spacing = tb.font_spacing;
        const text_size: Vec2 = .fromRaylib(raylib.measureTextEx(font, text, font_size, font_spacing));
        const texture = game.texture_manager.loadAssumeLoaded(tb_texture_name);

        texture.drawPro(
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(texture.width),
                .height = @floatFromInt(texture.height),
            },
            .{
                .x = tb_origin.x,
                .y = tb_origin.y,
                .width = tb_size.x,
                .height = tb_size.y,
            },
            tb_size.scale(0.5).toRaylib(),
            0,
            .white,
        );
        raylib.drawTextEx(
            font,
            text,
            tb_origin.subtract(text_size.scale(0.5)).toRaylib(),
            font_size,
            font_spacing,
            .white,
        );

        const choice = tb.choice orelse return;
        _ = choice;
        @panic("choices not handled yet!");
    }

    /// Figures out font size and such.
    pub fn init(text: [:0]const u8, font: Font, choice: ?Choice.Kind, id: u16) Textbox {
        const font_size: f32, const font_spacing: f32 = blk: { // Roughly estimate font size. TODO: Make a better algorith, for this.
            var guess: f32 = 256.0;
            while (true) {
                const size: Vec2 = .fromRaylib(raylib.measureTextEx(font, text, guess, guess / tb_spacing_size_correlation));
                if (size.x <= tb_size_inner.x and size.y <= tb_size_inner.y) {
                    break :blk .{ guess, guess / tb_spacing_size_correlation };
                }
                guess /= 1.2;
            }
        };

        return .{
            .text = text,
            .font = font,
            .font_size = font_size,
            .font_spacing = font_spacing,
            .choice = choice,
            .id = id,
        };
    }
};

pub const Choice = union (enum) {
    pub const Kind = @typeInfo(Choice).@"union".tag_type.?;

    yes_no: enum {
        yes,
        no,
    },
};

/// Returns `true` if the dialogue has concluded.
pub fn update(dialogue: *Dialogue, gpa: Allocator) GameObject.UpdateError!bool {
    const textbox = dialogue.textbox;
    if (textbox.choice) |_| {
        @panic("choices not yet implemented!");
    }

    if (raylib.isKeyPressed(.space)) {
        const maybe_result = try dialogue.callback(dialogue.*, gpa, null);
        if (maybe_result) |result| {
            dialogue.textbox = result;
        } else {
            return true;
        }
    }

    return false;
}

pub fn draw(dialogue: *Dialogue) void {
    dialogue.textbox.draw();
}
