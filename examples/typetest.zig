const std = @import("std");
const fintui = @import("fintui");

const error_style: fintui.Screen.Cell.Style = .{
    .fg = .{ .truecolor = .{ 255, 0, 0 } },
};
const typed_style: fintui.Screen.Cell.Style = .{};
const untyped_style: fintui.Screen.Cell.Style = .{
    .fg = .{ .truecolor = .{ 100, 100, 100 } },
};

const target_text = "Hello, World! Fintui is the best TUI library for Zig, right?";

const AppState = struct {
    typed_text: std.ArrayList(u8),
    completed: bool,

    pub fn deinit(s: *AppState, gpa: std.mem.Allocator) void {
        s.typed_text.deinit(gpa);
    }

    pub fn update(s: *AppState, tui: *fintui.Tui, stdin: std.Io.File) !enum { none, quit } {
        if (try fintui.event.poll(stdin.handle)) |event| {
            switch (event) {
                .key => |key| {
                    if (s.completed) {
                        if (@intFromEnum(key) == 'q' or key == .esc or key == .ctrl_c) return .quit;
                        if (@intFromEnum(key) == 'r') {
                            s.completed = false;
                            try tui.showCursor();
                            s.typed_text.clearRetainingCapacity();
                            return .none;
                        }
                    }

                    if (@intFromEnum(key) >= ' ' and @intFromEnum(key) <= '~') {
                        try s.typed_text.append(tui.gpa, @intFromEnum(key));
                        return .none;
                    }

                    switch (key) {
                        .backspace => _ = s.typed_text.pop(),
                        .esc, .ctrl_c => return .quit,
                        else => {},
                    }
                },
                else => {},
            }
        }

        if (std.mem.eql(u8, s.typed_text.items, target_text)) {
            s.completed = true;
            try tui.hideCursor();
        }

        return .none;
    }

    pub fn render(s: *AppState, tui: *fintui.Tui) !void {
        try tui.fill(.{});

        if (s.completed) {
            const message = "You got 0 WPM! Try better next time, you suck at typing.";
            const center_pos = tui.getCenterPos(message.len, 1);

            try tui.drawString(center_pos.x, center_pos.y - 1, "You got 0 WPM! Try better next time, you suck at typing.", .{});

            const keyhint = "[r] restart     [q] quit";
            const keyhint_pos = tui.getCenterPos(keyhint.len, 1);

            try tui.drawString(keyhint_pos.x, keyhint_pos.y + 1, keyhint, .{});
            return;
        }

        const center_pos = tui.getCenterPos(target_text.len, 1);

        try tui.drawString(center_pos.x, center_pos.y, target_text, untyped_style);
        try tui.moveCursor(@intCast(center_pos.x + s.typed_text.items.len), center_pos.y);

        for (s.typed_text.items, 0..) |char, i| {
            if (i >= target_text.len) {
                try tui.drawCell(@intCast(center_pos.x + i), center_pos.y, .{
                    .grapheme = char,
                    .style = error_style,
                });
                continue;
            }
            if (char == target_text[i]) {
                try tui.drawCell(@intCast(center_pos.x + i), center_pos.y, .{
                    .grapheme = char,
                    .style = typed_style,
                });
            } else if (target_text[i] != ' ') {
                try tui.drawCell(@intCast(center_pos.x + i), center_pos.y, .{
                    .grapheme = target_text[i],
                    .style = error_style,
                });
            } else {
                try tui.drawCell(@intCast(center_pos.x + i), center_pos.y, .{
                    .grapheme = char,
                    .style = error_style,
                });
            }
        }
    }
};

pub fn main(init: std.process.Init) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    var stdout_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const writer = &stdout.interface;

    const stdin = std.Io.File.stdin();

    var tui: fintui.Tui = try .init(
        init.gpa,
        writer,
        init.io,
    );
    defer tui.deinit() catch {};

    var state: AppState = .{
        .typed_text = .empty,
        .completed = false,
    };
    defer state.deinit(init.gpa);

    try tui.showCursor();

    while (true) {
        defer _ = arena.reset(.free_all);
        defer tui.render() catch {};

        _ = try tui.frameDelta(init.io, .fromNanoseconds(std.time.ns_per_s / 60)) orelse continue;

        switch (try state.update(&tui, stdin)) {
            .quit => break,
            .none => {},
        }

        try state.render(&tui);
    }
}
