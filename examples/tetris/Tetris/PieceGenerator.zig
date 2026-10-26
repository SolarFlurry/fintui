const std = @import("std");

const Tetris = @import("../Tetris.zig");
const Piece = Tetris.Piece;

const Self = @This();

rand: std.Random,
bag: struct {
    data: [7]u8,
    len: u8,
},

pub fn init(rand: std.Random) Self {
    var result: Self = .{
        .rand = rand,
        .bag = undefined,
    };

    result.reshuffleBag();

    return result;
}

pub fn reshuffleBag(s: *Self) void {
    s.bag.len = 7;
    for (0..7) |i| {
        s.bag.data[i] = @intCast(i);
    }
}

pub fn drawPiece(s: *Self) Piece {
    if (s.bag.len == 0) {
        s.reshuffleBag();
    }

    const idx = s.rand.uintLessThan(u8, s.bag.len);
    const result = s.bag.data[idx];

    s.bag.len -= 1;
    s.bag.data[idx] = s.bag.data[s.bag.len];

    return .{
        .kind = result,
        .rot = 0,
        .x = 3,
        .y = 0,
    };
}
