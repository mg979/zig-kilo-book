# The `ioctl` method

We'll first create two new modules:


| | |
|----------|----------|
| **types.zig** | hub for all the custom types of our editor         |
| **ansi.zig** | handles ansi escape sequences         |

In `src/types.zig` we'll write this:

<div class="code-title">types.zig</div>

```zig
//! Collection of types used by the editor.

///////////////////////////////////////////////////////////////////////////////
//
//                              Editor types
//
///////////////////////////////////////////////////////////////////////////////

/// Dimensions of the terminal screen where the editor runs.
pub const Screen = struct {
    rows: usize = 0,
    cols: usize = 0,
};
```

```admonish important
Zig supports default initializers in structs, but with some catch... more on
this later.
```

In `src/ansi.zig` we'll write this:

<div class="code-title">ansi.zig</div>

```zig
//! Module that handles ansi terminal sequences.

///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Get the window size.
pub fn getWindowSize() !t.Screen {
    // code to come...
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const linux = @import("linux.zig");
const t = @import("types.zig");
```

We should fill the `getWindowSize()` function.

<div class="code-title">ansi.zig: getWindowSize()</div>

```zig
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
```

Much like in the original C code, we use `ioctl()` to request the window size
of the terminal, and this will be stored in the `wsz` struct which we pass by
reference.

The `ioctl()` function returns `-1` on failure, but we consider a failure also
a column value of `0` in the passed `wsz` struct.

Note that in the second part of the condition (`wsz.col == 0`) `wsz` would
already have a value because it's assumed that the `ioctl()` call was
successful, since it didn't return `-1`.


## The `winsize()` function

We'll also have to update our `src/linux.zig` module to add the `winsize()`
function that is called in `getWindowSize()`:

<div class="code-title">linux.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Read the window size into the `wsz` struct.
pub fn winsize(wsz: *posix.winsize) usize {
    return linux.ioctl(STDOUT_FILENO, linux.T.IOCGWINSZ, @intFromPtr(wsz));
}
```

To know why `std.os.linux.ioctl` is invoked like that, we should look for it in
the Zig standard library:

<div class="code-title">std/os/linux.zig</div>

```zig
pub fn ioctl(fd: fd_t, request: u32, arg: usize) usize {
    return syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), request, arg);
}
```

The function doesn't have any documentation, so we just invoke it like we
invoked the one in the original written in C, where the call was:

<div class="code-title">C</div>

```c
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &wsz) == -1 || wsz.ws_col == 0)
```

The `TIOCGWINSZ` is replaced by the `linux.T.IOCGWINSZ` constant, found in
`std.os.linux` module of the Zig standard library.

The other difference is the third argument, that is `usize` in Zig, so we must
do a pointer cast to integer:

```zig
@intFromPtr(wsz)
```

```admonish important title="Reminder"
Remember to mark functions with the `pub` qualifier when they are called by
other modules.
```

```admonish note
I put this function in `linux` module because I preferred to keep all the low
level interactions with the operating system in it.
```
