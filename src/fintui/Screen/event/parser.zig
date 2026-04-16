const std = @import("std");
const event = @import("../event.zig");

pub fn parse(event_str: []const u8) ?event.Event {
    if (event_str.len == 0) return null;
}
