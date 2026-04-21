const std = @import("std");

pub const Event = union(enum) {
    mouse: Mouse,
    key: Key,
};

pub const Mouse = struct {
    x: u8,
    y: u8,
    state: enum(u8) {
        left_down = 0,
        middle_down = 1,
        right_down = 2,
        released = 3,
    },
};

pub const Key = enum(u8) {
    ctrl_a = 1,
    ctrl_b = 2,
    ctrl_c = 3,
    ctrl_d = 4,
    ctrl_e = 5,
    ctrl_f = 6,
    ctrl_g = 7,
    ctrl_h = 8,
    ctrl_i = 9,
    ctrl_j = 10,
    ctrl_k = 11,
    ctrl_l = 12,
    ctrl_m = 13,
    ctrl_n = 14,
    ctrl_o = 15,
    ctrl_p = 16,
    ctrl_q = 17,
    ctrl_r = 18,
    ctrl_s = 19,
    ctrl_t = 20,
    ctrl_u = 21,
    ctrl_v = 22,
    ctrl_w = 23,
    ctrl_x = 24,
    ctrl_y = 25,
    ctrl_z = 26,
    up = 252,
    down = 253,
    right = 254,
    left = 255,
    _,
};

pub fn poll(handle: std.posix.fd_t) !?Event {
    var buffer: [6]u8 = undefined;
    const read = try std.posix.read(handle, &buffer);
    if (read == 0) return null;
    return parse(buffer[0..read]);
}

fn parse(event_str: []const u8) ?Event {
    if (event_str.len > 2 and std.mem.eql(u8, event_str[0..2], "\x1b[")) {
        return switch (event_str[2]) {
            'M' => blk: { // mouse event
                if (event_str.len != 6) return null;
                if (event_str[3] > 67 or event_str[3] < 32) return null;

                break :blk .{
                    .mouse = .{
                        .x = event_str[4] - 33,
                        .y = event_str[5] - 33,
                        .state = @enumFromInt(event_str[3] % 32),
                    },
                };
            },
            'A' => .{ .key = .up },
            'B' => .{ .key = .down },
            'C' => .{ .key = .right },
            'D' => .{ .key = .left },
            else => null,
        };
    }

    if (event_str.len != 1) return null;

    return .{
        .key = @enumFromInt(event_str[0]),
    };
}
