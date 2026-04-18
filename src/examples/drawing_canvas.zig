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

    var mousePos: struct { x: u8, y: u8 } = .{
        .x = 0,
        .y = 0,
    };

    var mouseState: @FieldType(fintui.Screen.event.Mouse, "state") = .released;

    while (true) {
        defer _ = arena.reset(.free_all);
        defer screen.render() catch {};

        _ = screen.delta(io);

        try screen.writeString(0, 0, "Use 'q' to exit this demo!", .{});
        try screen.writeString(0, 1, "Use 'c' to clear the canvas", .{});

        const event = try screen.pollEvent(stdin.handle) orelse continue;

        switch (event) {
            .char => |key| {
                if (@intFromEnum(key) == 'q' or @intFromEnum(key) == 'Q') break;
                if (@intFromEnum(key) == 'c' or @intFromEnum(key) == 'C') {
                    try screen.fill(.{});
                    continue;
                }
            },
            .mouse => |mouse| {
                if (mouse.state != .left_down) try screen.changeCell(mousePos.x, mousePos.y, .{});
                mousePos.x = mouse.x;
                mousePos.y = mouse.y;
                mouseState = mouse.state;
            },
        }

        try screen.changeCell(mousePos.x, mousePos.y, .{
            .grapheme = if (mouseState == .released) '*' else '+',
        });
    }
}
