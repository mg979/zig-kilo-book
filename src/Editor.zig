//! Type that manages most of the editor functionalities.
//! It draws the main window, the statusline and the message area, and controls
//! the event loop.

/// Allocator used by the editor instance
alc: mem.Allocator,

/// The size of the terminal window where the editor runs
screen: t.Screen,

/// Text buffer the user is currently editing
buffer: t.Buffer,

/// Tracks cursor position and part of the buffer that fits the screen
view: t.View,

/// Becomes true when the main loop should stop, causing the editor to quit
should_quit: bool,

/// String that is printed on the terminal at every screen redraw
surface: t.Chars,

///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

/// Return the initialized editor instance.
pub fn init(allocator: mem.Allocator, screen: t.Screen) !Editor {
    // multiply * 10, because each cell could contain escape sequences
    const surface_capacity = screen.rows * screen.cols * 10;
    return .{
        .alc = allocator,
        .surface = try t.Chars.initCapacity(allocator, surface_capacity),
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
    e.surface.deinit(e.alc);
}

/// Start up the editor: open the path in args if valid, start the event loop.
pub fn startUp(e: *Editor, path: ?[]const u8) !void {
    if (path) |name| {
        try e.openFile(name);
    }
    else {
        // we generate the welcome message
    }

    while (e.should_quit == false) {
        try e.refreshScreen();
        try e.processKeypress();
    }
}

/// Read all lines from file.
fn readLines(e: *Editor, file: std.fs.File) !void {
    var buf: [1024]u8 = undefined;
    var reader = file.reader(&buf);

    var line_writer = std.Io.Writer.Allocating.init(e.alc);
    defer line_writer.deinit();

    while (reader.interface.streamDelimiter(&line_writer.writer, '\n')) |_| {
        try e.insertRow(e.buffer.rows.items.len, line_writer.written());
        line_writer.clearRetainingCapacity();
        reader.interface.toss(1); // skip the newline
    }
    else |err| if (err != error.EndOfStream) return err;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              File operations
//
///////////////////////////////////////////////////////////////////////////////

/// Open a file with `path`.
fn openFile(e: *Editor, path: []const u8) !void {
    var B = &e.buffer;

    // store the filename into the buffer
    B.filename = try e.updateString(B.filename, path);

    // read lines if the file could be opened
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only });
    if (file) |f| {
        defer f.close();
        try e.readLines(f);
    }
    else |err| switch (err) {
        error.FileNotFound => {}, // new unsaved file
        else => return err,
    }

    B.dirty = false;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Row operations
//
///////////////////////////////////////////////////////////////////////////////

/// Insert a row at index `ix` with content `line`, then update it.
fn insertRow(e: *Editor, ix: usize, line: []const u8) !void {
    const B = &e.buffer;

    var row = try t.Row.init(B.alc);
    try row.chars.appendSlice(B.alc, line);

    try B.rows.insert(B.alc, ix, row);

    try e.updateRow(ix);
    B.dirty = true;
}

/// Update row.render, that is the visual representation of the row.
/// Performs a syntax update at the end.
fn updateRow(e: *Editor, ix: usize) !void {
    const row = e.rowAt(ix);

    // get the length of the rendered row and reallocate
    const rlen = row.cxToRx(row.chars.items.len);
    row.render = try e.alc.realloc(row.render, rlen);

    var idx: usize = 0;
    var i: usize = 0;

    while (i < row.chars.items.len) : (i += 1) {
        if (row.chars.items[i] == '\t') {
            row.render[idx] = ' ';
            idx += 1;
            while (idx % opt.tabstop != 0) : (idx += 1) {
                row.render[idx] = ' ';
            }
        }
        else {
            row.render[idx] = row.chars.items[i];
            idx += 1;
        }
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
//                              Screen update
//
///////////////////////////////////////////////////////////////////////////////

/// Full refresh of the screen.
fn refreshScreen(e: *Editor) !void {
    e.surface.clearRetainingCapacity();

    try e.toSurface(ansi.BgDefault);
    try e.toSurface(ansi.HideCursor);
    try e.toSurface(ansi.CursorTopLeft);

    try e.drawRows();
    // try e.drawStatusline();
    // try e.drawMessageBar();

    const V = &e.view;

    // move cursor to its current position (could have been moved with keys)
    var buf: [32]u8 = undefined;
    const row = V.cy - V.rowoff + 1;
    const col = V.rx - V.coloff + 1;
    try e.toSurface(try ansi.moveCursorTo(&buf, row, col));

    try e.toSurface(ansi.ShowCursor);

    try linux.write(e.surface.items);
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Helpers
//
///////////////////////////////////////////////////////////////////////////////

/// Update the string, freeing the old one and allocating from `path`.
fn updateString(e: *Editor, old: ?[]u8, path: []const u8) ![]u8 {
    t.freeOptional(e.alc, old);
    return try e.alc.dupe(u8, path);
}

/// Get the row pointer at index `ix`.
fn rowAt(e: *Editor, ix: usize) *t.Row {
    return &e.buffer.rows.items[ix];
}

/// Get the row pointer at cursor position.
fn currentRow(e: *Editor) *t.Row {
    return &e.buffer.rows.items[e.view.cy];
}

/// Append either a slice or a character to the editor surface.
fn toSurface(e: *Editor, value: anytype) !void {
    switch (@typeInfo(@TypeOf(value))) {
        .pointer => try e.surface.appendSlice(e.alc, value),
        else => try e.surface.append(e.alc, value),
    }
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Tests
//
///////////////////////////////////////////////////////////////////////////////

test "insert rows" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    var e = try t.Editor.init(da.allocator(), .{ .rows = 50, .cols = 180 });
    try e.openFile("src/main.zig");
    defer e.deinit();

    const row = e.rowAt(6).chars.items;
    try expect(mem.eql(u8, "pub fn main() !void {", row));
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
const opt = @import("option.zig");
const linux = @import("linux.zig");

const mem = std.mem;
const expect = std.testing.expect;
