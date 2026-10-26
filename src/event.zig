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
    ctrl_at = 0,
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
    esc = 27,
    ctrl_backslash = 28,
    ctrl_rbrack = 29,
    ctrl_caret = 30,
    ctrl_underscore = 31,

    space,
    @"!",
    double_quote,
    @"#",
    @"$",
    @"%",
    @"&",
    single_quote,
    @"(",
    @")",
    star,
    plus,
    comma,
    minus,
    dot,
    slash,

    zero,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    colon,
    semicolon,

    @"<",
    equal,
    @">",
    @"?",
    @"@",

    upper_a,
    upper_b,
    upper_c,
    upper_d,
    upper_e,
    upper_f,
    upper_g,
    upper_h,
    upper_i,
    upper_j,
    upper_k,
    upper_l,
    upper_m,
    upper_n,
    upper_o,
    upper_p,
    upper_q,
    upper_r,
    upper_s,
    upper_t,
    upper_u,
    upper_v,
    upper_w,
    upper_x,
    upper_y,
    upper_z,

    @"[",
    backslash,
    @"]",
    @"^",
    underscore,
    backtick,

    lower_a,
    lower_b,
    lower_c,
    lower_d,
    lower_e,
    lower_f,
    lower_g,
    lower_h,
    lower_i,
    lower_j,
    lower_k,
    lower_l,
    lower_m,
    lower_n,
    lower_o,
    lower_p,
    lower_q,
    lower_r,
    lower_s,
    lower_t,
    lower_u,
    lower_v,
    lower_w,
    lower_x,
    lower_y,
    lower_z,

    backspace = 127,
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
