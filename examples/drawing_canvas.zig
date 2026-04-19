const std = @import("std");
const fintui = @import("fintui");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var threaded: std.Io.Threaded = .init(gpa.allocator(), .{});
    defer threaded.deinit();
    const io = threaded.io();

    var stdout_buf: [1024]u8 = undefined;

    var stdout = std.Io.File.stdout().writer(io, &stdout_buf);
    const writer = &stdout.interface;

    const stdin = std.Io.File.stdin();

    var screen = try fintui.Screen.init(
        gpa.allocator(),
        arena.allocator(),
        writer,
        io,
    );
    defer screen.deinit() catch {};

    var mouse_pos: struct { x: u8, y: u8 } = .{
        .x = 0,
        .y = 0,
    };

    var mouse_state: @FieldType(fintui.event.Mouse, "state") = .released;

    try screen.showCursor();

    while (true) {
        defer _ = arena.reset(.free_all);
        defer screen.render() catch {};

        _ = screen.delta(io);

        try screen.writeString(0, 0, "Use 'q' to exit this demo!", .{});
        try screen.writeString(0, 1, "Use 'c' to clear the canvas", .{});

        const event = try fintui.event.poll(stdin.handle) orelse continue;

        switch (event) {
            .char => |key| {
                if (@intFromEnum(key) == 'q' or @intFromEnum(key) == 'Q') break;
                if (@intFromEnum(key) == 'c' or @intFromEnum(key) == 'C') {
                    try screen.fill(.{});
                    continue;
                }
            },
            .mouse => |mouse| {
                if (mouse.state != .left_down) try screen.changeCell(mouse_pos.x, mouse_pos.y, .{});
                mouse_pos.x = mouse.x;
                mouse_pos.y = mouse.y;
                mouse_state = mouse.state;

                try screen.moveCursor(mouse_pos.x, mouse_pos.y);
            },
        }

        try screen.changeCell(mouse_pos.x, mouse_pos.y, .{
            .grapheme = if (mouse_state == .released) '*' else '+',
        });
    }
}
