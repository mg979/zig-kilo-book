//! A Buffer holds the representation of a file, divided in rows.
//! If modified, it is marked as dirty until saved.

alc: std.mem.Allocator,

// Modified state
dirty: bool,

// Buffer rows
rows: std.ArrayList(t.Row),

// Path of the file
filename: ?[]u8,

// Name of the syntax
syntax: ?[]const u8,

///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

pub fn init(allocator: std.mem.Allocator) !Buffer {
    return Buffer{
        .alc = allocator,
        .rows = try .initCapacity(allocator, initial_rows_capacity),
        .dirty = false,
        .filename = null,
        .syntax = null,
    };
}

pub fn deinit(buf: *Buffer) void {
    t.freeOptional(buf.alc, buf.filename);
    t.freeOptional(buf.alc, buf.syntax);
    for (buf.rows.items) |*row| {
        row.deinit(buf.alc);
    }
    buf.rows.deinit(buf.alc);
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const Buffer = @This();

const std = @import("std");
const t = @import("types.zig");

/// Initial allocation size for Buffer.rows
const initial_rows_capacity = 40;
