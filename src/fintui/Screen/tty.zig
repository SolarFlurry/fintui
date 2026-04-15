const std = @import("std");
const builtin = @import("builtin");

var original_termios: std.posix.system.termios = undefined;

comptime {
    if (builtin.os.tag != .macos and builtin.os.tag != .linux)
        @compileError("fintui supports MacOS and Linux only currently");
}

pub fn enableRawMode() !void {
    original_termios = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
    var raw = original_termios;
    raw.iflag.IGNBRK = false;
    raw.iflag.BRKINT = false;
    raw.iflag.PARMRK = false;
    raw.iflag.ISTRIP = false;
    raw.iflag.INLCR = false;
    raw.iflag.IGNCR = false;
    raw.iflag.ICRNL = false;
    raw.iflag.IXON = false;

    raw.oflag.OPOST = false;

    raw.lflag.ECHO = false;
    raw.lflag.ECHONL = false;
    raw.lflag.ICANON = false;
    raw.lflag.ISIG = false;
    raw.lflag.IEXTEN = false;

    raw.cflag.CSIZE = .CS8;
    raw.cflag.PARENB = false;

    raw.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, raw);
}

pub fn disableRawMode() !void {
    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, original_termios);
}

pub fn getTermSize() !struct { u16, u16 } {
    if (std.c.isatty(std.posix.STDIN_FILENO) != 1) @panic("Not in a TTY");

    var winsz = std.c.winsize{
        .row = 0,
        .col = 0,
        .xpixel = 0,
        .ypixel = 0,
    };

    const rv = std.posix.system.ioctl(std.posix.STDIN_FILENO, std.c.T.IOCGWINSZ, &winsz);
    if (rv == 0) {
        return .{ winsz.col, winsz.row };
    } else return error.UnexpectedErrNo;
}
