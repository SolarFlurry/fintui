const std = @import("std");
const fintui = @import("fintui");

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var stdout_buf: [1024]u8 = undefined;

    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const writer = &stdout.interface;

    const stdin = std.Io.File.stdin();

    var tui = try fintui.Tui.init(
        init.gpa,
        writer,
        init.io,
    );
    defer tui.deinit() catch {};

    var mouse_pos: struct { x: u8, y: u8 } = .{
        .x = 0,
        .y = 0,
    };

    var mouse_state: @FieldType(fintui.event.Mouse, "state") = .released;

    try tui.showCursor();

    while (true) {
        defer _ = arena.reset(.free_all);
        defer tui.render() catch {};

        _ = try tui.frameDelta(init.io, std.Io.Duration.fromNanoseconds(std.time.ns_per_s / 60)) orelse continue;

        try tui.drawString(0, 0, "Use 'q' to exit this demo!", .{});
        try tui.drawString(0, 1, "Use 'c' to clear the canvas", .{});

        const event = try fintui.event.poll(stdin.handle) orelse continue;

        switch (event) {
            .key => |key| {
                if (@intFromEnum(key) == 'q' or @intFromEnum(key) == 'Q') break;
                if (@intFromEnum(key) == 'c' or @intFromEnum(key) == 'C') {
                    try tui.fill(.{});
                    continue;
                }
            },
            .mouse => |mouse| {
                if (mouse.state != .left_down) try tui.drawCell(mouse_pos.x, mouse_pos.y, .{});
                mouse_pos.x = mouse.x;
                mouse_pos.y = mouse.y;
                mouse_state = mouse.state;

                try tui.moveCursor(mouse_pos.x, mouse_pos.y);
            },
        }

        try tui.drawCell(mouse_pos.x, mouse_pos.y, .{
            .grapheme = if (mouse_state == .released) '*' else '+',
        });
    }
}
