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

    var buf: [1]u8 = undefined;
    while (try readChar(&buf) == 1 and buf[0] != 'q') {}
}

// Read from stdin into `buf`, return the number of read characters
fn readChar(buf: []u8) !usize {
    const stdin = std.posix.STDIN_FILENO;
    return try std.posix.read(stdin, buf);
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
