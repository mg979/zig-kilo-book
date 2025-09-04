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
        // fallback method will be here
    } else {
        screen = t.Screen{
            .rows = wsz.row,
            .cols = wsz.col,
        };
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
