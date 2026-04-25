const std = @import("std");
const fintui = @import("fintui");

const logo =
    \\  ▄████  ▄█    ▄         ▗▅▘   ▄   ▄█ 
    \\  █▀   ▀ ██     █  ▄▁▁▁▂▟█▛     █  ██ 
    \\  █▀▀    ██ ██   █ ▝████▞▉  █    █ ██ 
    \\  █      ▐█ █ █  █     ▜▙▜▏  █   █ ▐█ 
    \\   █      ▐ █  █ █     ▕█▐   █▄ ▄█  ▐ 
    \\    ▀       █   ██~~~~~/~~|~~~▀▀▀     
;

const logo_width: u8 = 37;
const logo_height: u8 = 6;

const water_spout: []const []const u8 = &.{
    \\ __   ._
    \\.  \ /  \
    \\    .    
    ,
    \\ __   _.
    \\/  . /  \
    \\.   |    
    ,
    \\ _.   __
    \\/  \ /  .
    \\    .    
    ,
    \\ ._   __
    \\/  \ .  \
    \\    |   .
    ,
};

const water_spout_width: u8 = 9;
const water_spout_height: u8 = 3;

const description = "a simple Zig TUI library";

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

    var anim_progress: u8 = 0;

    while (true) {
        defer _ = arena.reset(.free_all);
        defer screen.render() catch {};

        const delta: f64 = screen.delta(init.io);
        const sleep_time = 0.1 - delta;
        if (sleep_time > 0) {
            try init.io.sleep(std.Io.Duration.fromNanoseconds(@trunc(sleep_time * std.time.ns_per_s)), .awake);
        }

        if (try fintui.event.poll(stdin.handle)) |event| {
            switch (event) {
                .key => |key| {
                    if (@intFromEnum(key) == 'q') break;
                },
                else => {},
            }
        }

        const x: u8 = @intCast((screen.width - logo_width) / 2);
        const y: u8 = @intCast((screen.height - logo_height) / 2);

        try screen.writeString(x, y, logo, .{});
        try screen.writeString(x + logo_width - 6, y - 3, water_spout[anim_progress / 3], .{
            .fg = .{
                .truecolor = .{ 12, 137, 232 },
            },
        });

        try screen.writeString(@intCast((screen.width - description.len) / 2), y + logo_height + 2, description, .{});

        anim_progress += 1;
        if (anim_progress >= water_spout.len * 3) anim_progress = 0;
    }
}
