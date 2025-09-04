//! A Row contains 3 arrays, one for the actual characters, one for how it is
//! rendered on the screen, and one with the highlight of each element of the
//! rendered array.

/// The ArrayList with the actual row characters
chars: t.Chars,

/// Array with the visual representation of the row
render: []u8,

///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

pub fn init(allocator: std.mem.Allocator) !Row {
    return Row{
        .chars = try .initCapacity(allocator, initial_row_size),
        .render = &.{},
    };
}

pub fn deinit(row: *Row, allocator: std.mem.Allocator) void {
    row.chars.deinit(allocator);
    allocator.free(row.render);
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Methods
//
///////////////////////////////////////////////////////////////////////////////

/// Length of the real row.
pub fn clen(row: *Row) usize {
    return row.chars.items.len;
}

/// Length of the rendered row.
pub fn rlen(row: *Row) usize {
    return row.render.len;
}

/// Calculate the position of a real column in the rendered row.
pub fn cxToRx(row: *Row, cx: usize) usize {
    var rx: usize = 0;
    for (0..cx) |i| {
        if (row.chars.items[i] == '\t') {
            rx += (opt.tabstop - 1) - (rx % opt.tabstop);
        }
        rx += 1;
    }
    return rx;
}

/// Calculate the position of a rendered column in the real row.
pub fn rxToCx(row: *Row, rx: usize) usize {
    var cur_rx: usize = 0;
    var cx: usize = 0;
    while (cx < row.chars.items.len) : (cx += 1) {
        if (row.chars.items[cx] == '\t') {
            cur_rx += (opt.tabstop - 1) - (cur_rx % opt.tabstop);
        }
        cur_rx += 1;

        if (cur_rx > rx) {
            return cx;
        }
    }
    return cx;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const Row = @This();

const std = @import("std");

const t = @import("types.zig");
const opt = @import("option.zig");

const initial_row_size = 80;
