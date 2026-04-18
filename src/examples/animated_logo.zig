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

    var anim_progress: f64 = 0;

    while (true) {
        defer _ = arena.reset(.free_all);
        defer screen.render() catch {};

        const delta = screen.delta(io);

        if (try screen.pollEvent(stdin.handle)) |event| {
            switch (event) {
                .char => |key| {
                    if (@intFromEnum(key) == 'q') break;
                },
                else => {},
            }
        }

        const x: u8 = @intCast((screen.width - logo_width) / 2);
        const y: u8 = @intCast((screen.height - logo_height) / 2);

        try screen.writeString(x, y, logo, .{});
        try screen.writeString(x + logo_width - 6, y - 3, water_spout[@trunc(anim_progress)], .{
            .fg = .{
                .truecolor = .{ 12, 137, 232 },
            },
        });

        try screen.writeString(@intCast((screen.width - description.len) / 2), y + logo_height + 2, description, .{});

        anim_progress += delta * 5;
        if (anim_progress >= water_spout.len) anim_progress = 0;
    }
}
