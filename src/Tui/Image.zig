const std = @import("std");

const Image = @This();

id: u32,

pub const Source = union(enum) {
    path: []const u8,
    rgb: []const [3]u8,
    rgba: []const [4]u8,
};
