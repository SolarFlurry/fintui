const std = @import("std");
const Cell = @This();

grapheme: u21 = ' ', // Cell character can be a unicode codepoint
style: Style = .{},

pub const Modifiers = enum(u8) {
    none,
    bold,
    italic,
    bold_italic,
};

pub fn equals(a: Cell, b: Cell) bool {
    return a.grapheme == b.grapheme and a.style.equals(b.style);
}

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

    pub fn equals(a: Style, b: Style) bool {
        return a.fg.equals(b.fg) and a.bg.equals(b.bg);
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

    pub fn equals(a: Color, b: Color) bool {
        if (@as(std.meta.Tag(Color), a) != @as(std.meta.Tag(Color), b)) return false;

        return switch (a) {
            .index => a.index == b.index,
            .truecolor => std.mem.eql(u8, &a.truecolor, &b.truecolor),
        };
    }
};
