///////////////////////////////////////////////////////////////////////////////
//
//                              Main function
//
///////////////////////////////////////////////////////////////////////////////

pub fn main() !void {
    orig_termios = try linux.enableRawMode();
    defer linux.disableRawMode(orig_termios);

    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = switch (builtin.mode) {
        .Debug => da.allocator(),
        else => std.heap.smp_allocator,
    };
    _ = allocator;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Panic handler
//
///////////////////////////////////////////////////////////////////////////////

pub const panic = std.debug.FullPanic(crashed);

fn crashed(msg: []const u8, trace: ?usize) noreturn {
    linux.disableRawMode(orig_termios);
    std.debug.defaultPanic(msg, trace);
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const builtin = @import("builtin");

const linux = @import("linux.zig");

var orig_termios: std.os.linux.termios = undefined;
