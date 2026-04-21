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

    var screen = try fintui.Screen.init(
        init.gpa,
        frame_alloc,
        writer,
        init.io,
    );
    defer screen.deinit() catch {};

    while (true) {
        defer _ = arena.reset(.free_all);
        defer screen.render() catch {};

        _ = screen.delta(init.io);

        if (try fintui.event.poll(stdin.handle)) |event| {
            switch (event) {
                .key => |key| {
                    if (key == .ctrl_c) break;
                    try screen.writeString(0, 0, "                                          ", .{});
                    const text = try std.fmt.allocPrint(frame_alloc, "Event: {s}", .{switch (key) {
                        _ => &.{@intFromEnum(key)},
                        else => @tagName(key),
                    }});
                    try screen.writeString(0, 0, text, .{});
                },
                else => {},
            }
        }
    }
}
