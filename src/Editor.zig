//! Type that manages most of the editor functionalities.
//! It draws the main window, the statusline and the message area, and controls
//! the event loop.

/// Allocator used by the editor instance
alc: std.mem.Allocator,

/// The size of the terminal window where the editor runs
screen: t.Screen,

/// Text buffer the user is currently editing
buffer: t.Buffer,

/// Tracks cursor position and part of the buffer that fits the screen
view: t.View,

/// Becomes true when the main loop should stop, causing the editor to quit
should_quit: bool,

///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

/// Return the initialized editor instance.
pub fn init(allocator: std.mem.Allocator, screen: t.Screen) !Editor {
    return .{
        .alc = allocator,
        .screen = .{
            .rows = screen.rows - 2, // make room for statusline/message area
            .cols = screen.cols,
        },
        .buffer = try t.Buffer.init(allocator),
        .view = .{},
        .should_quit = false,
    };
}

/// Deinitialize the editor.
pub fn deinit(e: *Editor) void {
    e.buffer.deinit();
}

/// Start up the editor: open the path in args if valid, start the event loop.
pub fn startUp(e: *Editor, path: ?[]const u8) !void {
    if (path) |name| {
        _ = name;
        // we open the file
    }
    else {
        // we generate the welcome message
    }

    while (e.should_quit == false) {
        // refresh the screen
        try e.processKeypress();
    }
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Keys processing
//
///////////////////////////////////////////////////////////////////////////////

/// Process a keypress: will wait indefinitely for readKey, which loops until
/// a key is actually pressed.
fn processKeypress(e: *Editor) !void {
    const k = try ansi.readKey();

    const static = struct {
        var q: u8 = 3;
    };

    switch (k) {
        .ctrl_q => {
            if (static.q > 1) {
                static.q -= 1;
                return;
            }
            try ansi.clearScreen();
            e.should_quit = true;
        },
        else => {},
    }

    // reset quit counter for any keypress that isn't Ctrl-Q
    static.q = 3;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const Editor = @This();

const std = @import("std");

const t = @import("types.zig");
const ansi = @import("ansi.zig");
