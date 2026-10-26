const std = @import("std");
const fintui = @import("fintui");

const Tetris = @import("Tetris.zig");

const Allocator = std.mem.Allocator;

const main_style: fintui.Screen.Cell.Style = .{ .bg = .rgb(36, 39, 58) };

fn outOfBounds(x: i32, y: i32) bool {
    return x < 0 or x >= 10 or y < 0 or y >= 20;
}

fn drawStringCenter(tui: *fintui.Tui, x: u16, y: u16, string: []const u8, style: fintui.Screen.Cell.Style) fintui.Tui.DrawError!void {
    const mid_x = (tui.screen.width - string.len) / 2 + x;

    try tui.drawString(@intCast(mid_x), @intCast(y), string, style);
}

const target_delta: std.Io.Duration = .fromNanoseconds(std.time.ns_per_s / 60);

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const page_size = std.heap.pageSize();

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

    var prng = std.Random.DefaultPrng.init(seed: {
        var seed: u64 = undefined;
        init.io.random(std.mem.asBytes(&seed));
        break :seed seed;
    });
    const rand = prng.random();

    var tetris: Tetris = try .init(gpa, rand);
    defer tetris.deinit(gpa);

    var paused = false;

    gameloop: while (true) {
        defer _ = arena.reset(.{ .retain_with_limit = page_size });
        defer tui.render() catch {};

        _ = try tui.frameDelta(init.io, target_delta) orelse continue;

        if (paused) continue;

        try tui.fill(.{ .style = main_style });

        if (!paused) switch (tetris.game_state) {
            .over => {
                const y = tui.screen.height / 2 - 10;

                try drawStringCenter(&tui, 0, @intCast(y - 4), "Game OVER", main_style);
                try drawStringCenter(&tui, 0, y - 3, "Press SPACE to play again", main_style);
            },
            .dropping => tetris.game_state.stateDropping(),
            .row_clear => tetris.game_state.stateRowClear(),
            .place_piece => tetris.game_state.statePlacePiece(),
            .lock_delay => tetris.game_state.stateLockDelay(),
            .exit => break :gameloop,
        };

        if (try fintui.event.poll(stdin.handle)) |event| blk: {
            if (event == .key and event.key == .lower_p) {
                paused = !paused;
            }
            if (paused) break :blk;
            if (tetris.game_state == .over) {
                tetris.handleGameOverEvent(event);
            } else {
                tetris.handlePlayingEvent(event);
            }
        }

        try tetris.render(&tui);
    }
}
