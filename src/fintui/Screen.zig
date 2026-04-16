const std = @import("std");

const Cell = @import("Screen/Cell.zig");
const Color = @import("Screen/Color.zig");
const tty = @import("Screen/tty.zig");
pub const event = @import("Screen/event.zig");
const Event = event.Event;

const Self = @This();

gpa: std.mem.Allocator,
frame_arena: std.mem.Allocator, // an arena that should be resetted every frame
out: *std.Io.Writer,
changes: Changes,
data: []Cell,
width: u32,
height: u32,

pub const ChangeError = error{
    OutOfBounds,
} || std.mem.Allocator.Error;

pub const Changes = std.MultiArrayList(struct {
    x: u16,
    y: u16,
    change: Cell,
});

pub fn init(gpa: std.mem.Allocator, frame_arena: std.mem.Allocator, out: *std.Io.Writer) !Self {
    const winsize = try tty.getTermSize();
    var result: Self = .{
        .data = try gpa.alloc(Cell, winsize.@"0" * winsize.@"1"),
        .width = winsize.@"0",
        .height = winsize.@"1",
        .changes = .empty,
        .gpa = gpa,
        .frame_arena = frame_arena,
        .out = out,
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

pub fn getCell(self: *Self, x: u32, y: u32) *Cell {
    return &self.data[y * self.width + x];
}

pub fn isInside(self: *const Self, x: u32, y: u32) bool {
    return x >= 0 or y >= 0 or x < self.width or y < self.height;
}

/// Adding more changes after calling this method, before calling `render`, will
/// result in a runtime panic. It is not recommended to use this method.
pub fn fill(self: *Self, cell: Cell) !void {
    for (self.data) |*c| {
        c.* = cell;
    }
    self.changes.len = self.width * self.height;
}

pub fn changeCell(self: *Self, x: u16, y: u16, change: Cell) ChangeError!void {
    if (x >= self.width or x < 0 or y >= self.height or y < 0) return error.OutOfBounds;
    const target_cell = self.getCell(x, y);
    if (target_cell.grapheme == change.grapheme) return;

    try self.changes.append(self.frame_arena, .{
        .change = change,
        .x = x,
        .y = y,
    });
    target_cell.* = change;
}

pub fn writeString(self: *Self, x: u16, y: u16, string: []const u8, style: Cell.Style) ChangeError!void {
    var iter: std.unicode.Utf8Iterator = .{
        .i = 0,
        .bytes = string,
    };
    var i = x;
    while (iter.nextCodepoint()) |grapheme| {
        try self.changeCell(i, y, .{
            .grapheme = grapheme,
            .style = style,
        });
        i += 1;
    }
}

/// This should only be called once a frame, after all changes have been accumulated
pub fn render(self: *Self) !void {
    if (self.changes.len > self.width * self.height / 2) {
        try self.fullRender();
        return;
    }

    for (0..self.changes.len) |i| {
        const change = self.changes.items(.change)[i];
        try self.out.print("\x1b[{d};{d}H\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m{u}", .{
            self.changes.items(.y)[i] + 1,
            self.changes.items(.x)[i] + 1,
            change.style.fg.r,
            change.style.fg.g,
            change.style.fg.b,
            change.style.bg.r,
            change.style.bg.g,
            change.style.bg.b,
            change.grapheme,
        });
    }
    self.changes = .empty;

    try self.out.flush();
}

fn fullRender(self: *Self) !void {
    try self.out.writeAll("\x1b[H");
    for (0..self.height) |j| {
        for (0..self.width) |i| {
            const cell = self.getCell(@intCast(i), @intCast(j));
            try self.out.print("\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m{u}", .{
                cell.style.fg.r,
                cell.style.fg.g,
                cell.style.fg.b,
                cell.style.bg.r,
                cell.style.bg.g,
                cell.style.bg.b,
                cell.grapheme,
            });
            try self.out.printUnicodeCodepoint(self.getCell(@intCast(i), @intCast(j)).grapheme);
        }
        if (j == self.height - 1) break;
        try self.out.writeAll("\r\n");
    }
    self.changes.len = 0;

    try self.out.flush();
}

pub fn pollEvent(_: *Self, handle: std.posix.fd_t) !?Event {
    var buffer: [6]u8 = undefined;
    const read = try std.posix.read(handle, &buffer);

    if (read == 0) return null;

    if (read == 6 and std.mem.eql(u8, buffer[0..3], "\x1b[M")) {
        if (buffer[3] > 67 or buffer[3] < 32) return null;

        return .{
            .mouse = .{
                .x = buffer[4] - 33,
                .y = buffer[5] - 33,
                .state = @enumFromInt(buffer[3] % 32),
            },
        };
    }

    if (read != 1) return null;

    return .{
        .char = @enumFromInt(buffer[0]),
    };
}
