//! Module that handles ansi terminal sequences.

///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Get the window size.
pub fn getWindowSize() !t.Screen {
    var screen: t.Screen = undefined;
    var wsz: std.posix.winsize = undefined;

    if (linux.winsize(&wsz) == -1 or wsz.col == 0) {
        screen = try getCursorPosition();
    } else {
        screen = t.Screen{
            .rows = wsz.row,
            .cols = wsz.col,
        };
    }
    return screen;
}

/// Get the cursor position, to determine the window size.
pub fn getCursorPosition() !t.Screen {
    var buf: [32]u8 = undefined;

    try linux.write(WinMaximize ++ ReadCursorPos);

    var nread = try linux.readChars(&buf);
    if (nread < 5) return error.CursorError;

    // we should ignore the final R character
    if (buf[nread - 1] == 'R') {
        nread -= 1;
    }
    // not there yet? we will ignore it, but it should be there
    else if (try linux.readChars(buf[nread..]) != 1 or buf[nread] != 'R') {
        return error.CursorError;
    }

    if (buf[0] != ESC or buf[1] != '[') return error.CursorError;

    var screen = t.Screen{};
    var semicolon: bool = false;
    var digits: u8 = 0;

    // no sscanf, format to read is "row;col"
    // read it right to left, so we can read number of digits
    // stop before the CSI, so at index 2
    var i = nread;
    while (i > 2) {
        i -= 1;
        if (buf[i] == ';') {
            semicolon = true;
            digits = 0;
        }
        else if (semicolon) {
            screen.rows += (buf[i] - '0') * try std.math.powi(usize, 10, digits);
            digits += 1;
        } else {
            screen.cols += (buf[i] - '0') * try std.math.powi(usize, 10, digits);
            digits += 1;
        }
    }
    if (screen.cols == 0 or screen.rows == 0) {
        return error.CursorError;
    }
    return screen;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const linux = @import("linux.zig");
const t = @import("types.zig");

/// Control Sequence Introducer: ESC key, followed by '[' character
pub const CSI = "\x1b["

/// The ESC character
pub const ESC = '\x1b';

// Sets the number of column and rows to very high numbers, trying to maximize
// the window.
pub const WinMaximize = CSI ++ "999C" ++ CSI ++ "999B";

// Reports the cursor position (CPR) by transmitting ESC[n;mR, where n is the
// row and m is the column
pub const ReadCursorPos = CSI ++ "6n";
