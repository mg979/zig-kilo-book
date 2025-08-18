# The linux module

Create a file `src/linux.zig` and paste the following content:

<div class="code-title">linux.md</div>

```zig
//! Module that handles interactions with the operating system.

///////////////////////////////////////////////////////////////////////////////
//
//                              Raw mode
//
///////////////////////////////////////////////////////////////////////////////

/// Enable terminal raw mode, return previous configuration.
pub fn enableRawMode() !linux.termios {
    const orig_termios = try posix.tcgetattr(STDIN_FILENO);

    // stuff here

    return orig_termios;
}

/// Disable terminal raw mode by restoring the saved configuration.
pub fn disableRawMode(termios: linux.termios) void {
    posix.tcsetattr(STDIN_FILENO, .FLUSH, termios) catch @panic("Disabling raw mode failed!");
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;

const STDOUT_FILENO = posix.STDOUT_FILENO;
const STDIN_FILENO = posix.STDIN_FILENO;
```

For now, we have two functions:

| | |
|----------|----------|
| **enableRawMode**   | should change the terminal configuration, switching away from canonical mode, then should return the original configuration         |
| **disableRawMode**  | should restore the original configuration         |


We have to fill the `enableRawMode` function, since right now it's not doing
anything.

