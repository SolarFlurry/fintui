const std = @import("std");
const Tetris = @import("../Tetris.zig");

const Cell = Tetris.Cell;

const Piece = @This();

x: i8,
y: i8,
rot: u2,
kind: u8,

pub const piece_table: *const [7] // 7 tetrominos
[4] // 4 rotations for each
u16 // 4x4 grid of cells
= &.{
    generateTetrominoData(
        \\....
        \\####
        \\....
        \\....
    ),
    generateTetrominoData(
        \\....
        \\.##.
        \\.##.
        \\....
    ),
    generateTetrominoData(
        \\.#.
        \\###
        \\...
    ),
    generateTetrominoData(
        \\.##
        \\##.
        \\...
    ),
    generateTetrominoData(
        \\##.
        \\.##
        \\...
    ),
    generateTetrominoData(
        \\#..
        \\###
        \\...
    ),
    generateTetrominoData(
        \\..#
        \\###
        \\...
    ),
};

pub const piece_colors: [7]Cell = .{
    .light_blue,
    .yellow,
    .purple,
    .green,
    .red,
    .dark_blue,
    .orange,
};

pub fn getData(s: Piece) u16 {
    return piece_table[s.kind][s.rot];
}

const Range = struct { min_x: u8, min_y: u8, max_x: u8, max_y: u8 };

pub fn posRange(s: Piece) Range {
    const piece_data = s.getData();

    var result: Range = .{
        .min_x = 3,
        .min_y = 3,
        .max_x = 0,
        .max_y = 0,
    };

    for (0..4) |j| {
        for (0..4) |i| {
            const piece_block_here = (piece_data >> @intCast(j * 4 + i)) & 1 == 1;
            if (piece_block_here) {
                if (i < result.min_x) result.min_x = @intCast(i);
                if (i > result.max_x) result.max_x = @intCast(i);
                if (j < result.min_y) result.min_y = @intCast(j);
                if (j > result.max_y) result.max_y = @intCast(j);
            }
        }
    }

    return result;
}

fn generateTetrominoData(comptime piece_pic: []const u8) [4]u16 {
    if (!@inComptime()) unreachable;

    const width: i8 = width: for (piece_pic, 0..) |c, i| {
        if (c == '\n') break :width @intCast(i);
    } else @compileError("Could not deduce width of tetromino");

    if (width > 4) @compileError("The width of the piece is over 4");

    if (piece_pic.len != width * (width + 1) - 1) @compileError("The height and width of the piece is not equal");

    var piece_data: u16 = 0;

    for (0..width) |j| {
        if (j < (width - 1) and piece_pic[j * (width + 1) + width] != '\n') @compileError("Inconsistent widths in piece");

        for (0..width) |i| {
            switch (piece_pic[j * (width + 1) + i]) {
                '.' => {},
                '#' => piece_data |= 1 << (j * 4 + i),
                else => @compileError("Unexpected piece character"),
            }
        }
    }

    var rotations: [4]u16 = @splat(0);
    rotations[0] = piece_data;

    var previous_rot = piece_data;

    for (1..4) |idx| {
        for (0..width) |j| {
            for (0..width) |i| {
                const value = (previous_rot >> (j * 4 + i)) & 1;
                const x_rot: u4 = @intCast(width - 1 - j);
                const y_rot: u4 = @intCast(i);

                rotations[idx] |= value << (y_rot * 4 + x_rot);
            }
        }
        previous_rot = rotations[idx];
    }

    return rotations;
}
