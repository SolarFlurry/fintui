const std = @import("std");
const fintui = @import("fintui");

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const frame_alloc = arena.allocator();
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

    while (true) {
        defer _ = arena.reset(.free_all);
        defer tui.render() catch {};

        const delta = try tui.frameDelta(init.io, .fromNanoseconds(std.time.ns_per_s / 60)) orelse continue;

        if (try fintui.event.poll(stdin.handle)) |event| {
            switch (event) {
                .key => |key| {
                    if (@intFromEnum(key) == 'q') break;
                },
                else => {},
            }
        }

        try tui.drawString(0, 0, try std.fmt.allocPrint(
            frame_alloc,
            "FPS: {d:.2}            ",
            .{@as(f64, @floatFromInt(std.time.ns_per_s)) / @as(f64, @floatFromInt(delta.toNanoseconds()))},
        ), .{});
    }
}
