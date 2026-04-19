const std = @import("std");

const Cell = @import("Screen/Cell.zig");
const Color = Cell.Color;
const tty = @import("Screen/tty.zig");

const Self = @This();

gpa: std.mem.Allocator,
frame_arena: std.mem.Allocator, // an arena that should be resetted every frame
out: *std.Io.Writer,
changes: Changes,
data: []Cell,
width: u32,
height: u32,
last_time: std.Io.Timestamp,
cursor: struct {
    visibility: enum(u8) {
        hidden,
        shown,
    },
    x: u8,
    y: u8,
},

pub const ChangeError = error{
    OutOfBounds,
} || std.mem.Allocator.Error;

pub const Changes = std.MultiArrayList(union(enum) {
    rect: struct {
        x: u8,
        y: u8,
        width: u8,
        height: u8,
        change: Cell,
    },
    cell: struct {
        x: u8,
        y: u8,
        change: Cell,
    },
});

pub fn init(gpa: std.mem.Allocator, frame_arena: std.mem.Allocator, out: *std.Io.Writer, io: std.Io) !Self {
    const winsize = try tty.getTermSize();
    var result: Self = .{
        .data = try gpa.alloc(Cell, winsize.@"0" * winsize.@"1"),
        .width = winsize.@"0",
        .height = winsize.@"1",
        .changes = .empty,
        .gpa = gpa,
        .frame_arena = frame_arena,
        .out = out,
        .last_time = std.Io.Timestamp.now(io, .awake),
        .cursor = .{
            .x = 0,
            .y = 0,
            .visibility = .hidden,
        },
    };

    try tty.enableRawMode();

    for (result.data) |*cell| {
        cell.* = .{};
    }

    try out.writeAll("\x1b 7\x1b[?1049h\x1b[2J\x1b[?25l\x1b[?1003h");
    try result.fullRender();

    return result;
}

pub fn deinit(self: *Self) !void {
    self.changes.deinit(self.gpa);
    self.gpa.free(self.data);
    try tty.disableRawMode();
    try self.out.writeAll("\x1b[?1003l\x1b[?1049l\x1b[?25h\x1b 8");
    try self.out.flush();
}

/// This calculates the delta in seconds. Use once per frame.
pub fn delta(self: *Self, io: std.Io) f64 {
    const current_time = std.Io.Timestamp.now(io, .awake);
    const elapsed = self.last_time.durationTo(current_time);

    const dt = @as(f64, @floatFromInt(elapsed.nanoseconds)) / std.time.ns_per_s;

    self.last_time = current_time;
    return dt;
}

pub fn getCell(self: *Self, x: u32, y: u32) *Cell {
    return &self.data[y * self.width + x];
}

pub fn isInside(self: *const Self, x: u32, y: u32) bool {
    return x >= 0 or y >= 0 or x < self.width or y < self.height;
}

pub fn fill(self: *Self, cell: Cell) !void {
    try self.rectCell(0, 0, @intCast(self.width), @intCast(self.height), cell);
}

pub fn changeCell(self: *Self, x: u8, y: u8, change: Cell) ChangeError!void {
    if (x >= self.width or x < 0 or y >= self.height or y < 0) return error.OutOfBounds;
    const target_cell = self.getCell(x, y);
    if (target_cell.grapheme == change.grapheme) return;

    try self.changes.append(self.frame_arena, .{ .cell = .{
        .change = change,
        .x = x,
        .y = y,
    } });
    target_cell.* = change;
}

pub fn rectCell(self: *Self, x: u8, y: u8, width: u8, height: u8, change: Cell) ChangeError!void {
    if (x + width > self.width or x < 0 or y + height > self.height or y < 0) return error.OutOfBounds;

    try self.changes.append(self.frame_arena, .{ .rect = .{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .change = change,
    } });

    for (0..height) |j| {
        for (0..width) |i| {
            const target_cell = self.getCell(@intCast(x + i), @intCast(y + j));
            target_cell.* = change;
        }
    }
}

// '\n' in the `string` parameter will be interpreted as a newline and will cause
// the changes to go down a line
pub fn writeString(self: *Self, x: u8, y: u8, string: []const u8, style: Cell.Style) ChangeError!void {
    var iter: std.unicode.Utf8Iterator = .{
        .i = 0,
        .bytes = string,
    };
    var i = x;
    var j = y;
    while (iter.nextCodepoint()) |grapheme| {
        if (grapheme == '\n') {
            j += 1;
            i = x;
            continue;
        }
        try self.changeCell(i, j, .{
            .grapheme = grapheme,
            .style = style,
        });
        i += 1;
    }
}

pub fn showCursor(self: *Self) !void {
    if (self.cursor.visibility == .shown) return;
    self.cursor.visibility = .shown;
    try self.out.writeAll("\x1b[?25h");
}

pub fn hideCursor(self: *Self) !void {
    if (self.cursor.visibility == .hidden) return;
    self.cursor.visibility = .hidden;
    try self.out.writeAll("\x1b[?25l");
}

pub fn moveCursor(self: *Self, x: u8, y: u8) !void {
    self.cursor.x = x;
    self.cursor.y = y;
}

/// This should only be called once a frame, after all changes have been accumulated
pub fn render(self: *Self) !void {
    if (self.changes.len > self.width * self.height) {
        try self.fullRender();
        return;
    }

    for (0..self.changes.len) |i| {
        switch (self.changes.get(i)) {
            .cell => |cell| {
                try self.out.print("\x1b[{d};{d}H", .{ cell.y + 1, cell.x + 1 });
                try cell.change.style.ansi(self.out);
                try self.out.printUnicodeCodepoint(cell.change.grapheme);
            },
            .rect => |rect| {
                try rect.change.style.ansi(self.out);
                for (0..rect.height) |j| {
                    try self.out.print("\x1b[{d};{d}H", .{ rect.y + j + 1, rect.x + 1 });
                    for (0..rect.width) |_| {
                        try self.out.printUnicodeCodepoint(rect.change.grapheme);
                    }
                }
            },
        }
    }
    self.changes = .empty;

    if (self.cursor.visibility == .shown) {
        try self.out.print("\x1b[{d};{d}H", .{ self.cursor.y + 1, self.cursor.x + 1 });
    }

    try self.out.flush();
}

fn fullRender(self: *Self) !void {
    try self.out.writeAll("\x1b[H");
    for (0..self.height) |j| {
        for (0..self.width) |i| {
            const cell = self.getCell(@intCast(i), @intCast(j));
            try cell.style.ansi(self.out);
            try self.out.printUnicodeCodepoint(cell.grapheme);
        }
        if (j == self.height - 1) break;
        try self.out.writeAll("\r\n");
    }
    self.changes.len = 0;

    try self.out.flush();
}
