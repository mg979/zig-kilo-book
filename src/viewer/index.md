# A text viewer

Right now we're able to open a file and display it, but not being able to move
the cursor, keeps us stuck in the top-left corner of the screen.

Our `processKeypress()` must detect more keys, and we must bind these keys to
actions to perform.

We change our function to this:

<div class="code-title">Editor.zig</div>

```zig
/// Process a keypress: will wait indefinitely for readKey, which loops until
/// a key is actually pressed.
fn processKeypress(e: *Editor) !void {
    const k = try ansi.readKey();

    const static = struct {
        var q: u8 = opt.quit_times;
    };

    const B = &e.buffer;

    switch (k) {
        .ctrl_q => {
            if (B.dirty and static.q > 0) {
                static.q -= 1;
                return;
            }
            try ansi.clearScreen();
            e.should_quit = true;
        },
        else => {},
    }

    // reset quit counter for any keypress that isn't Ctrl-Q
    static.q = opt.quit_times;
}
```

### opt.quit_times

First thing, we want to remove that magic number and bind `static.q` to an
option, so in `option.zig` we'll add:

<div class="code-title">option.zig</div>

```zig
pub const quit_times = 3;
```

and we replace `3` with `opt.quit_times`. And we only want to repeat
<kbd>Ctrl-Q</kbd> if the buffer has modified.

Next, we'll handle more keypresses.
