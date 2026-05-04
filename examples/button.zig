const std = @import("std");
const fintui = @import("fintui");

fn drawOutlineBox(tui: *fintui.Tui, x: u16, y: u16, width: u16, height: u16, style: fintui.Screen.Cell.Style) !void {
    for (0..height) |j| {
        try tui.drawCell(x, @intCast(y + j), .{
            .grapheme = if (j == 0) '╭' else if (j == height - 1) '╰' else '│',
            .style = style,
        });
        if (j == 0 or j == height - 1) {
            for (0..width - 2) |i| {
                try tui.drawCell(@intCast(x + i + 1), @intCast(y + j), .{
                    .grapheme = '─',
                    .style = style,
                });
            }
        }
        try tui.drawCell(@intCast(x + width - 1), @intCast(y + j), .{
            .grapheme = if (j == 0) '╮' else if (j == height - 1) '╯' else '│',
            .style = style,
        });
    }
}

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

    const message = "the button";

    const Rect = struct {
        x: u16,
        y: u16,
        width: u16,
        height: u16,
    };

    const button: Rect = .{
        .x = @intCast((tui.screen.width - message.len - 8) / 2),
        .y = @intCast((tui.screen.height - 5) / 2),
        .width = message.len + 8,
        .height = 5,
    };

    var button_down: u8 = 0;

    while (true) {
        defer _ = arena.reset(.free_all);
        defer tui.render() catch {};

        _ = try tui.frameDelta(init.io, .fromNanoseconds(std.time.ns_per_s / 60)) orelse continue;

        if (try fintui.event.poll(stdin.handle)) |event| {
            switch (event) {
                .key => |key| {
                    if (@intFromEnum(key) == 'q') break;
                },
                .mouse => |mouse| if (mouse.state == .left_down) {
                    if (mouse.x >= button.x and mouse.x < button.x + button.width and mouse.y >= button.y and mouse.y < button.y + button.height) {
                        button_down = 20;
                    }
                },
            }
        }
        try tui.fill(.{});

        if (button_down > 0) {
            button_down -= 1;
            try drawOutlineBox(&tui, button.x, button.y + 1, button.width, button.height, .{
                .fg = .{ .index = .red },
            });
            try tui.drawString(@intCast((tui.screen.width - message.len) / 2), @intCast((tui.screen.height - 1) / 2 + 1), message, .{});
        } else {
            try drawOutlineBox(&tui, button.x, button.y, button.width, button.height, .{
                .fg = .{ .index = .red },
            });
            try tui.drawString(@intCast((tui.screen.width - message.len) / 2), @intCast((tui.screen.height - 1) / 2), message, .{});
            try tui.drawString(button.x, button.y + button.height, "╰" ++ ("─" ** (message.len + 6)) ++ "╯", .{
                .fg = .{ .index = .black },
            });
        }
    }
}
