# First test

```admonish important
This test will be special because it needs an interactive terminal, it will not
be executed with:

    zig build test

but with:

    zig test src/term_tests.zig

It will be the only test of this kind, unfortunately it's also the first one.
```

We want to test if our functions work. Specifically, we'll test the
`getWindowSize()` and `getCursorPosition()`, which also test setting raw mode
and `readChars()` along the way.

We'll add a couple of constants at the bottom of `ansi.zig`:

<div class="code-title">ansi.zig</div>

```zig
const builtin = @import("builtin");

// CSI sequence to clear the screen.
pub const ClearScreen = CSI ++ "2J" ++ CSI ++ "H";
```

We'll create a new file named `src/term_tests.zig`, with this content:

<div class="code-title">term_tests.zig</div>

```zig
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
```

We'll clear the screen after having called the second method, because that
function call has the side-effect of maximizing the terminal screen, which
messes up the output of the test result.

To ensure that our `getWindowSize()` works and doesn't fallback, we must add
a check in that function:

<div class="code-title">ansi.zig: getWindowSize()</div>

<div class="code-diff-added">

```zig
    if (linux.winsize(&wsz) == -1 or wsz.col == 0) {
```
</div>

```zig
        if (builtin.is_test) return error.getWindowSizeFailed;
```

This will cause the function to error out, if the `ioctl` method fails.
We will then get the window size with the fallback method, and ensure the
resulting sizes are the same.
