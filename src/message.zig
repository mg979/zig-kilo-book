//! Module that holds various strings for the message area, either status or
//! error messages, or prompts.

const std = @import("std");
const opt = @import("option.zig");

const status_messages = .{
    .{ "welcome", "Kilo editor -- version " ++ opt.version_str },
    .{ "help", "HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find" },
    .{ "unsaved", "WARNING!!! File has unsaved changes. Press Ctrl-Q {d} more times to quit." },
    .{ "bufwrite", "\"{s}\" {d} lines, {d} bytes written" },
};

const error_messages = .{
    .{ "ioerr", "Can't save! I/O error: {s}" },
};

pub const status = std.StaticStringMap([]const u8).initComptime(status_messages);
pub const errors = std.StaticStringMap([]const u8).initComptime(error_messages);
