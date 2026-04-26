const std = @import("std");
const fintui = @import("fintui");

const target_delta: f64 = 0.05;
const snake_color = [3]u8{ 80, 181, 93 };

const Dir = enum(u8) {
    up = 252,
    down,
    right,
    left,

    pub fn opposite(dir: Dir) Dir {
        return switch (dir) {
            .up => .down,
            .down => .up,
            .right => .left,
            .left => .right,
        };
    }
};

const Pos = struct {
    x: u16,
    y: u16,
};

fn randomPos(rand: std.Random, screen: *const fintui.Screen) Pos {
    return .{
        .x = rand.intRangeAtMost(u16, 1, @intCast(screen.width - 2)),
        .y = rand.intRangeAtMost(u16, 1, @intCast(screen.height - 2)),
    };
}

fn resetSnake(gpa: std.mem.Allocator, screen: *const fintui.Screen, body: *std.Deque(Dir), head: *Pos, dir: *Dir) !void {
    body.deinit(gpa);
    body.* = .empty;
    try body.pushFrontSlice(gpa, &(.{.right} ** 20));
    head.* = .{
        .x = @intCast((screen.width + body.len) / 2),
        .y = @intCast(screen.height / 2),
    };
    dir.* = .right;
}

fn renderSnake(screen: *fintui.Screen, body: *const std.Deque(Dir), head: Pos) !void {
    var temp_pos = head;
    var iter = body.iterator();
    while (iter.next()) |dir| {
        screen.writeCell(temp_pos.x, temp_pos.y, .{
            .style = .{
                .bg = .{ .truecolor = snake_color },
            },
        }) catch |err| {
            if (err != error.OutOfBounds) return err;
        };

        switch (dir) {
            .up => temp_pos.y += 1,
            .down => temp_pos.y -= 1,
            .right => temp_pos.x -= 1,
            .left => temp_pos.x += 1,
        }
    }
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const frame_alloc = arena.allocator();
    defer arena.deinit();

    var stdout_buf: [1024]u8 = undefined;

    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const writer = &stdout.interface;

    const stdin = std.Io.File.stdin();

    var screen = try fintui.Screen.init(
        init.gpa,
        frame_alloc,
        writer,
        init.io,
    );
    defer screen.deinit() catch {};

    var prng = std.Random.DefaultPrng.init(seed: {
        var seed: u64 = undefined;
        init.io.random(std.mem.asBytes(&seed));
        break :seed seed;
    });
    const rand = prng.random();

    var game_mode: enum {
        start,
        playing,
        over,
    } = .start;

    var snake_body: std.Deque(Dir) = .empty;
    defer snake_body.deinit(init.gpa);
    var snake_head: Pos = undefined;
    var snake_dir: Dir = undefined;

    var snake_growth: u8 = 0;

    var tick: u8 = 0;

    try resetSnake(
        init.gpa,
        &screen,
        &snake_body,
        &snake_head,
        &snake_dir,
    );

    var food: Pos = randomPos(rand, &screen);

    gameloop: while (true) {
        defer _ = arena.reset(.free_all);
        defer screen.render() catch {};

        const delta: f64 = screen.delta(init.io);
        const sleep_time = target_delta - delta;
        if (sleep_time > 0) {
            try init.io.sleep(std.Io.Duration.fromNanoseconds(@trunc(sleep_time * std.time.ns_per_s)), .awake);
        }
        if (delta < target_delta) continue;

        if (game_mode != .playing) {
            const message = "Press any key to start";

            const y: u16 = @intCast(screen.height / 2);

            try screen.writeString(@intCast((screen.width - message.len) / 2), y + 2, message, .{});

            try renderSnake(&screen, &snake_body, snake_head);

            if (game_mode == .over) {
                try screen.writeString(@intCast((screen.width - 9) / 2), y - 2, "Game Over", .{});
            } else {
                try screen.writeString(@intCast((screen.width - 5) / 2), y - 2, "Snake", .{});
            }

            if (try fintui.event.poll(stdin.handle)) |event| {
                switch (event) {
                    .key => |key| {
                        if (key == .ctrl_c) break;
                        try resetSnake(
                            init.gpa,
                            &screen,
                            &snake_body,
                            &snake_head,
                            &snake_dir,
                        );
                        snake_growth = 0;
                        tick = 0;
                        food = randomPos(rand, &screen);
                        game_mode = .playing;
                    },
                    else => {},
                }
            }
            continue;
        }

        if (try fintui.event.poll(stdin.handle)) |event| {
            switch (event) {
                .key => |key| {
                    if (key == .ctrl_c) break;
                    if (@intFromEnum(key) >= 252 and @intFromEnum(snake_dir.opposite()) != @intFromEnum(key)) {
                        snake_dir = @enumFromInt(@intFromEnum(key));
                    }
                },
                else => {},
            }
        }

        switch (snake_dir) {
            .up => {
                if (snake_head.y == 0) {
                    game_mode = .over;
                    continue :gameloop;
                }
                snake_head.y -= 1;
            },
            .down => {
                if (snake_head.y == screen.height - 1) {
                    game_mode = .over;
                    continue :gameloop;
                }
                snake_head.y += 1;
            },
            .right => {
                if (snake_head.x == screen.width - 1) {
                    game_mode = .over;
                    continue :gameloop;
                }
                snake_head.x += 1;
            },
            .left => {
                if (snake_head.x == 0) {
                    game_mode = .over;
                    continue :gameloop;
                }
                snake_head.x -= 1;
            },
        }

        if (snake_head.x == food.x and snake_head.y == food.y) {
            food = randomPos(rand, &screen);
            snake_growth = 5;
        }
        if (snake_growth == 0) {
            _ = snake_body.popBack();
        } else {
            snake_growth -= 1;
        }

        try snake_body.pushFront(init.gpa, snake_dir);

        const cell_at_head = screen.getCell(snake_head.x, snake_head.y);
        switch (cell_at_head.style.bg) {
            .truecolor => |rgb| {
                if (std.mem.eql(u8, &rgb, &snake_color)) {
                    game_mode = .over;
                    continue :gameloop;
                }
            },
            else => {},
        }

        try screen.fill(.{});

        try renderSnake(&screen, &snake_body, snake_head);
        try screen.writeCell(food.x, food.y, .{
            .style = .{
                .bg = .{ .truecolor = .{ 255, 0, 0 } },
            },
        });
    }
}
