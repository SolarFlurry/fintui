const std = @import("std");

const Tui = @This();
const tty = @import("Tui/tty.zig");
const Screen = @import("Screen.zig");
const Cell = Screen.Cell;
const DrawError = Screen.ChangeError;

gpa: std.mem.Allocator,
frame_arena: std.mem.Allocator,
out: *std.Io.Writer,
screen: Screen,
last_time: std.Io.Timestamp,

pub fn init(gpa: std.mem.Allocator, frame_arena: std.mem.Allocator, out: *std.Io.Writer, io: std.Io) !Tui {
    const winsize = try tty.getTermSize();

    try tty.enableRawMode();

    try out.writeAll("\x1b 7\x1b[?1049h\x1b[?25l\x1b[?1003h");

    return .{
        .gpa = gpa,
        .frame_arena = frame_arena,
        .out = out,
        .screen = try .init(gpa, winsize.@"0", winsize.@"1", out),
        .last_time = std.Io.Timestamp.now(io, .awake),
    };
}

pub fn deinit(self: *Tui) !void {
    try self.screen.deinit(self.gpa);
    try tty.disableRawMode();
    try self.out.writeAll("\x1b[?1003l\x1b[?25h\x1b[?1049l\x1b 8");
    try self.out.flush();
}

/// This calculates the delta in seconds. Use once per frame.
pub fn delta(self: *Tui, io: std.Io) std.Io.Duration {
    const current_time = std.Io.Timestamp.now(io, .awake);
    const elapsed = self.last_time.durationTo(current_time);
    self.last_time = current_time;

    return elapsed;
}

/// This should only be called once a frame
pub fn render(self: *Tui) !void {
    try self.screen.render(self.out);
}

pub fn drawCell(self: *Tui, x: u16, y: u16, cell: Cell) DrawError!void {
    return self.screen.writeCell(x, y, cell);
}

// '\n' in the `string` parameter will be interpreted as a newline and will cause
// the changes to go down a line
pub fn drawString(self: *Tui, x: u16, y: u16, string: []const u8, style: Cell.Style) DrawError!void {
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
        try self.drawCell(i, j, .{
            .grapheme = grapheme,
            .style = style,
        });
        i += 1;
    }
}

pub fn drawRect(self: *Tui, x: u16, y: u16, width: u16, height: u16, cell: Cell) DrawError!void {
    if (x + width > self.screen.width or x < 0 or y + height > self.screen.height or y < 0) return error.OutOfBounds;

    for (0..height) |j| {
        for (0..width) |i| {
            const target_cell = self.screen.readCell(@intCast(x + i), @intCast(y + j));
            target_cell.* = cell;
        }
    }
}

pub fn fill(self: *Tui, cell: Cell) DrawError!void {
    try self.drawRect(0, 0, @intCast(self.screen.width), @intCast(self.screen.height), cell);
}

pub fn showCursor(self: *Tui) !void {
    try self.screen.showCursor(self.out);
}

pub fn hideCursor(self: *Tui) !void {
    try self.screen.hideCursor(self.out);
}

pub fn moveCursor(self: *Tui, x: u16, y: u16) !void {
    try self.screen.moveCursor(x, y);
}
