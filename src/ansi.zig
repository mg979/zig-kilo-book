//! Module that handles ansi terminal sequences.

///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Clear the screen.
pub fn clearScreen() !void {
    try linux.write(ClearScreen);
}

/// Get the window size.
pub fn getWindowSize() !t.Screen {
    var screen: t.Screen = undefined;
    var wsz: std.posix.winsize = undefined;

    if (linux.winsize(&wsz) == -1 or wsz.col == 0) {
        if (builtin.is_test) return error.getWindowSizeFailed;
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

/// Return the escape sequence to move the cursor to a position.
pub fn moveCursorTo(buf: []u8, row: usize, col: usize) ![]const u8 {
    return std.fmt.bufPrint(buf, CSI ++ "{};{}H", .{ row, col });
}

/// Read a character from stdin. Wait until at least one character is
/// available.
pub fn readKey() !t.Key {
    // we read a sequence of characters in a buffer
    var seq: [4]u8 = undefined;
    const nread = try linux.readChars(&seq);

    // if the first character is ESC, it could be part of an escape sequence
    // in this case, nread will be > 2, that means that more than two
    // characters have been read into the buffer, and it's an escape sequence
    // for sure, if we can't recognize this sequence we return ESC anyway

    const k: t.Key = @enumFromInt(seq[0]);

    if (k == .esc and nread > 2) {
        if (seq[1] == '[') {
            if (nread > 3 and asc.isDigit(seq[2])) {
                if (seq[3] == '~') {
                    switch (seq[2]) {
                        '1' => return .home,
                        '3' => return .del,
                        '4' => return .end,
                        '5' => return .page_up,
                        '6' => return .page_down,
                        '7' => return .home,
                        '8' => return .end,
                        else => {},
                    }
                }
            }
            switch (seq[2]) {
                'A' => return .up,
                'B' => return .down,
                'C' => return .right,
                'D' => return .left,
                'H' => return .home,
                'F' => return .end,
                else => {},
            }
        }
        else if (seq[1] == 'O') {
            switch (seq[2]) {
                'H' => return .home,
                'F' => return .end,
                else => {},
            }
        }
        return .esc;
    }
    else if (nread > 1) {
        return .esc;
    }
    return k;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const builtin = @import("builtin");

const asc = std.ascii;

const linux = @import("linux.zig");
const t = @import("types.zig");

/// Control Sequence Introducer: ESC key, followed by '[' character
pub const CSI = "\x1b[";

/// The ESC character
pub const ESC = '\x1b';

// Sets the number of column and rows to very high numbers, trying to maximize
// the window.
pub const WinMaximize = CSI ++ "999C" ++ CSI ++ "999B";

// Reports the cursor position (CPR) by transmitting ESC[n;mR, where n is the
// row and m is the column
pub const ReadCursorPos = CSI ++ "6n";

// CSI sequence to clear the screen.
pub const ClearScreen = CSI ++ "2J" ++ CSI ++ "H";

/// Background color
pub const BgDefault = CSI ++ "40m";

/// Foreground color
pub const FgDefault = CSI ++ "39m";

/// Hide the terminal cursor
pub const HideCursor = CSI ++ "?25l";

/// Show the terminal cursor
pub const ShowCursor = CSI ++ "?25h";

/// Move cursor to position 1,1
pub const CursorTopLeft = CSI ++ "H";

/// Start reversing colors
pub const ReverseColors = CSI ++ "7m";

/// Reset colors to terminal default
pub const ResetColors = CSI ++ "m";

/// Clear the content of the line
pub const ClearLine = CSI ++ "K";

/// Color used for error messages
pub const ErrorColor = CSI ++ "91m";
