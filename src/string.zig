//! Module with functions handling strings.

///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Return `true` if slices have the same content.
pub fn eql(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

/// Return `true` if the tail of haystack is exactly `needle`.
pub fn isTail(haystack: []const u8, needle: []const u8) bool {
    const idx = mem.lastIndexOfLinear(u8, haystack, needle);
    return idx != null and idx.? + needle.len == haystack.len;
}

/// Get the extension of a filename.
pub fn getExtension(path: []u8) ?[]u8 {
    const ix = mem.lastIndexOfScalar(u8, path, '.');
    if (ix == null or ix == path.len - 1) {
        return null;
    }
    return path[ix.? + 1 ..];
}

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

/// Return true if character is a separator (not a word character).
pub fn isSeparator(c: u8) bool {
    if (c == ' ' or c == '\t') return true;
    return switch (c) {
        '0'...'9', 'a'...'z', 'A'...'Z', '_' => false,
        else => true,
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
