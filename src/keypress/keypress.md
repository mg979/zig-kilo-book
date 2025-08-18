# Keypress processing

Before starting to draw anything, let's handle keypresses, because it's easier,
shorter, and as a bonus we'll have a way to quit the editor if we build it
(remember that our raw mode disables <kbd>Ctrl-C</kbd>).

By the way, did you follow my advice to install `ctags`? Because from now on,
we'll move very often from function to function, file to file, and having to
spend half a minute to find something kills completely the fun, believe me.

This is our event loop in `Editor.startUp()`:

<div class="code-diff-removed">

```zig
    while (e.should_quit == false) {
        // refresh the screen
        // process keypresses
    }
```
</div>

```zig
    while (e.should_quit == false) {
        // refresh the screen
        try e.processKeypress();
    }
```

Let's create the function:

<div class="code-title">Editor.zig</div>

```zig
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
```

This function calls `ansi.readKey()` (which we didn't write yet), then handle
the keypress. The only keypress that we handle for now is <kbd>Ctrl-Q</kbd>,
and we want to press it 3 times in a row before quitting.

It needs to import `ansi.zig`:

<div class="code-title">Editor.zig</div>

```zig
const ansi = @import("ansi.zig");
```

### Static variables in Zig

See that `static` struct? Zig doesn't have the concept of static variables that
are local to a function, like in C. But you can achieve the same effect by
declaring a constant struct inside the function, and define _variables_ (not
fields!) inside of it. You don't need to call it `static`, of course, it can
have any name.

And that `.ctrl_q`? It's an enum field, of an enum that we didn't write yet.

```admonish note title="Things we're missing"

We can't compile yet. We must add:

- `Key` enum
- `ansi.readKey()`
- `ansi.clearScreen()`
```
