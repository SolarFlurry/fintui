const std = @import("std");

grapheme: u21 = ' ', // Cell character can be a unicode codepoint
style: Style = .{},

pub const Modifiers = enum(u8) {
    none,
    bold,
    italic,
    bold_italic,
};

pub const Style = struct {
    fg: Color = .default,
    bg: Color = .default,
    modifiers: Modifiers = .none,

    pub fn ansi(self: Style, writer: *std.Io.Writer) !void {
        try writer.writeAll("\x1b[3");
        try self.fg.ansi(writer);
        try writer.writeAll(";4");
        try self.bg.ansi(writer);
        try writer.writeByte('m');
    }
};

pub const Color = union(enum) {
    index: enum(u8) {
        black = 0,
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        white,
        default = 9,
    },
    truecolor: [3]u8,

    pub const rgb_black: Color = .{
        .truecolor = .{ 0, 0, 0 },
    };

    pub const rgb_white = .{
        .truecolor = .{ 255, 255, 255 },
    };

    pub const default: Color = .{ .index = .default };

    pub fn ansi(self: Color, writer: *std.Io.Writer) !void {
        switch (self) {
            .index => |index| {
                try writer.print("{d}", .{@intFromEnum(index)});
            },
            .truecolor => |rgb| {
                try writer.print("8;2;{d};{d};{d}", .{ rgb[0], rgb[1], rgb[2] });
            },
        }
    }
};
