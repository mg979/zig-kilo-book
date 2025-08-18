# The message area

For the message area we'll need more Editor fields:

<div class="code-title">Editor.zig</div>

```zig
/// String to be printed in the message area (can be a prompt)
status_msg: t.Chars,

/// Controls the visibility of the status message
status_msg_time: i64,
```

Also add these constants:

<div class="code-title">Editor.zig</div>

```zig
const time = std.time.timestamp;
const time_ms = std.time.milliTimestamp;

const initial_msg_size = 80;
```

Add to `init()`:

<div class="code-title">Editor.zig: init()</div>

```zig
        .status_msg = try t.Chars.initCapacity(allocator, initial_msg_size),
        .status_msg_time = 0,
```

and to `deinit()` (always deinitialize ArrayLists or they will leak):

<div class="code-title">Editor.zig: deinit()</div>

```zig
    e.status_msg.deinit(e.alc);
```

Uncomment the line in `refreshScreen()` where we draw the message area.

<div class="code-title">Editor.zig: refreshScreen()</div>

```zig
    try e.drawRows();
    try e.drawStatusline();
```

<div class="code-diff-removed">

```zig
    // try e.drawMessageBar();
```
</div>

<div class="code-diff-added-top">

```zig
    try e.drawMessageBar();
```
</div>

### The `drawMessageBar()` function

I put this below `finalizeStatusline()`:

<div class="code-title">Editor.zig</div>

```zig
/// Append the message bar to the surface.
fn drawMessageBar(e: *Editor) !void {
    try e.toSurface(ansi.ClearLine);

    var msglen = e.status_msg.items.len;
    if (msglen > e.screen.cols) {
        msglen = e.screen.cols;
    }
    if (msglen > 0 and time() - e.status_msg_time < 5) {
        try e.toSurface(e.status_msg.items[0 .. msglen]);
    }
}
```

As you can see, it's pretty simple. We clear the line, then if there's
a message to be printed, we append it to the surface.

We have also some sort of timer: it's not a _real_ timer in the sense that
there's not an async timer that runs independently from the main thread.
Remember that the screen is redrawn in the event loop, whose iterations are
controlled by the `processKeypress()` function, since it's that function that
halts the loop while waiting for new keys pressed by the user. So what this
"timer" does, is to check if 5 seconds have passed since the last redraw, then
it will append the message to the surface if it didn't, otherwise it will not
append anything, and the message won't be printed.

It will be the function which sets a status message that will update
`status_msg_time`, but we don't have a way to set a status message yet.
