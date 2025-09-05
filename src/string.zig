//! Module with functions handling strings.

///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Return the number of leading whitespace characters
pub fn leadingWhitespaces(src: []u8) usize {
    var i: usize = 0;
    while (i < src.len and asc.isWhitespace(src[i])) : (i += 1) {}
    return i;
}

/// Return true if `c` is a word character.
pub fn isWord(c: u8) bool {
    return switch (c) {
        '0'...'9', 'a'...'z', 'A'...'Z', '_' => true,
        else => false,
    };
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const asc = std.ascii;
const mem = std.mem;
