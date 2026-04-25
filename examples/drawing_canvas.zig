const std = @import("std");
const fintui = @import("fintui");

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var stdout_buf: [1024]u8 = undefined;

    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const writer = &stdout.interface;

    const stdin = std.Io.File.stdin();

    var screen = try fintui.Screen.init(
        init.gpa,
        arena.allocator(),
        writer,
        init.io,
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

        const delta = screen.delta(init.io);
        const sleep_time = 1.0 / 60.0 - delta;
        if (sleep_time > 0) {
            try init.io.sleep(std.Io.Duration.fromNanoseconds(@trunc(sleep_time * std.time.ns_per_s)), .awake);
        }

        try screen.writeString(0, 0, "Use 'q' to exit this demo!", .{});
        try screen.writeString(0, 1, "Use 'c' to clear the canvas", .{});

        const event = try fintui.event.poll(stdin.handle) orelse continue;

        switch (event) {
            .key => |key| {
                if (@intFromEnum(key) == 'q' or @intFromEnum(key) == 'Q') break;
                if (@intFromEnum(key) == 'c' or @intFromEnum(key) == 'C') {
                    try screen.fill(.{});
                    continue;
                }
            },
            .mouse => |mouse| {
                if (mouse.state != .left_down) try screen.writeCell(mouse_pos.x, mouse_pos.y, .{});
                mouse_pos.x = mouse.x;
                mouse_pos.y = mouse.y;
                mouse_state = mouse.state;

                try screen.moveCursor(mouse_pos.x, mouse_pos.y);
            },
        }

        try screen.writeCell(mouse_pos.x, mouse_pos.y, .{
            .grapheme = if (mouse_state == .released) '*' else '+',
        });
    }
}
