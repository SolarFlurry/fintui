const Color = @import("Color.zig");

grapheme: u21 = ' ', // Cell character can be a unicode codepoint
style: Style = .{},

pub const Modifiers = enum(u8) {
    none,
    bold,
    italic,
    bold_italic,
};

pub const Style = struct {
    fg: Color = .Black,
    bg: Color = .Black,
    modifiers: Modifiers = .none,
};
