//! Additional tests that need an interactive terminal, not testable with:
//!
//!     zig build test
//!
//! Must be tested with:
//!
//!     zig test src/term_tests.zig

test "getWindowSize" {
    const orig_termios = try linux.enableRawMode();
    defer linux.disableRawMode(orig_termios);

    const s1 = try ansi.getWindowSize();
    try std.testing.expect(s1.rows > 0 and s1.cols > 0);
    const s2 = try ansi.getCursorPosition();
    try linux.write(ansi.ClearScreen);
    try std.testing.expect(s1.rows == s2.rows and s1.cols == s2.cols);
}

const std = @import("std");
const linux = @import("linux.zig");
const ansi = @import("ansi.zig");
