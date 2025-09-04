//! Module that handles interactions with the operating system.

///////////////////////////////////////////////////////////////////////////////
//
//                              Raw mode
//
///////////////////////////////////////////////////////////////////////////////

/// Enable terminal raw mode, return previous configuration.
pub fn enableRawMode() !linux.termios {
    const orig_termios = try posix.tcgetattr(STDIN_FILENO);

    // stuff here

    return orig_termios;
}

/// Disable terminal raw mode by restoring the saved configuration.
pub fn disableRawMode(termios: linux.termios) void {
    posix.tcsetattr(STDIN_FILENO, .FLUSH, termios) catch @panic("Disabling raw mode failed!");
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;

const STDOUT_FILENO = posix.STDOUT_FILENO;
const STDIN_FILENO = posix.STDIN_FILENO;
