const std = @import("std");

pub const Cell = @import("Screen/Cell.zig");
const Color = Cell.Color;

const Self = @This();

front_buffer: []Cell,
back_buffer: []Cell,
width: u32,
height: u32,
cursor: struct {
    visibility: enum(u8) {
        hidden,
        shown,
    },
    x: u16,
    y: u16,
},

pub const ChangeError = error{
    OutOfBounds,
};

pub fn init(gpa: std.mem.Allocator, width: u16, height: u16, out: *std.Io.Writer) !Self {
    var result: Self = .{
        .front_buffer = try gpa.alloc(Cell, width * height),
        .back_buffer = try gpa.alloc(Cell, width * height),
        .width = width,
        .height = height,
        .cursor = .{
            .x = 0,
            .y = 0,
            .visibility = .hidden,
        },
    };

    for (result.front_buffer) |*cell| {
        cell.* = .{};
    }

    try result.fullRender(out);

    return result;
}

pub fn deinit(self: *Self, gpa: std.mem.Allocator) !void {
    gpa.free(self.front_buffer);
    gpa.free(self.back_buffer);
}

pub fn readCell(self: *Self, x: u32, y: u32) *Cell {
    return &self.front_buffer[y * self.width + x];
}

pub fn writeCell(self: *Self, x: u16, y: u16, change: Cell) ChangeError!void {
    if (x >= self.width or x < 0 or y >= self.height or y < 0) return error.OutOfBounds;
    const target_cell = self.readCell(x, y);
    target_cell.* = change;
}

pub fn isInside(self: *const Self, x: u32, y: u32) bool {
    return x >= 0 and y >= 0 and x < self.width and y < self.height;
}

pub fn showCursor(self: *Self, out: *std.Io.Writer) !void {
    if (self.cursor.visibility == .shown) return;
    self.cursor.visibility = .shown;
    try out.writeAll("\x1b[?25h");
}

pub fn hideCursor(self: *Self, out: *std.Io.Writer) !void {
    if (self.cursor.visibility == .hidden) return;
    self.cursor.visibility = .hidden;
    try out.writeAll("\x1b[?25l");
}

pub fn moveCursor(self: *Self, x: u16, y: u16) !void {
    self.cursor.x = x;
    self.cursor.y = y;
}

/// This method, as opposed to `fullRender`, diffs the front and back buffers.
/// This should only be called once a frame
pub fn render(self: *Self, out: *std.Io.Writer) !void {
    for (0..self.height) |j| {
        var i: usize = 0;
        while (i < self.width) {
            var back_cell = &self.back_buffer[j * self.width + i];
            var front_cell = self.front_buffer[j * self.width + i];

            if (back_cell.equals(front_cell)) {
                i += 1;
                continue;
            }

            try out.print("\x1b[{d};{d}H", .{ j + 1, i + 1 });
            try front_cell.style.ansi(out);
            const style = front_cell.style;

            while (i < self.width and !front_cell.equals(back_cell.*) and
                front_cell.style.equals(style))
            {
                try out.printUnicodeCodepoint(front_cell.grapheme);
                back_cell.* = front_cell;
                i += 1;
                back_cell = &self.back_buffer[j * self.width + i];
                front_cell = self.front_buffer[j * self.width + i];
            }
        }
    }

    if (self.cursor.visibility == .shown) {
        try out.print("\x1b[{d};{d}H", .{ self.cursor.y + 1, self.cursor.x + 1 });
    }

    try out.flush();
}

fn fullRender(self: *Self, out: *std.Io.Writer) !void {
    try out.writeAll("\x1b[H");
    for (0..self.height) |j| {
        for (0..self.width) |i| {
            const cell = self.readCell(@intCast(i), @intCast(j));
            try cell.style.ansi(out);
            try out.printUnicodeCodepoint(cell.grapheme);
        }
        if (j == self.height - 1) break;
        try out.writeAll("\r\n");
    }

    try out.flush();

    @memcpy(self.back_buffer, self.front_buffer);
}
