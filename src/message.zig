//! Module that holds various strings for the message area, either status or
//! error messages, or prompts.

const std = @import("std");
const opt = @import("option.zig");

const status_messages = .{
    .{ "welcome", "Kilo editor -- version " ++ opt.version_str },
};

pub const status = std.StaticStringMap([]const u8).initComptime(status_messages);
