//! Module that handles interactions with the operating system.

///////////////////////////////////////////////////////////////////////////////
//
//                              Raw mode
//
///////////////////////////////////////////////////////////////////////////////

/// Enable terminal raw mode, return previous configuration.
pub fn enableRawMode() !linux.termios {
    const orig_termios = try posix.tcgetattr(STDIN_FILENO);

    // make a copy
    var termios = orig_termios;

    termios.lflag.ECHO = false; // don't echo input characters
    termios.lflag.ICANON = false; // read input byte-by-byte instead of line-by-line
    termios.lflag.ISIG = false; // disable Ctrl-C and Ctrl-Z signals
    termios.iflag.IXON = false; // disable Ctrl-S and Ctrl-Q signals
    termios.lflag.IEXTEN = false; // disable Ctrl-V
    termios.iflag.ICRNL = false; // CTRL-M being read as CTRL-J
    termios.oflag.OPOST = false; // disable output processing
    termios.iflag.BRKINT = false; // break conditions cause SIGINT signal
    termios.iflag.INPCK = false; // disable parity checking (obsolete?)
    termios.iflag.ISTRIP = false; // disable stripping of 8th bit
    termios.cflag.CSIZE = .CS8; // set character size to 8 bits

    // Set read timeouts
    termios.cc[@intFromEnum(linux.V.MIN)] = 0; // Return immediately when any bytes are available
    termios.cc[@intFromEnum(linux.V.TIME)] = 1; // Wait up to 0.1 seconds for input

    // update config
    try posix.tcsetattr(STDIN_FILENO, .FLUSH, termios);

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
