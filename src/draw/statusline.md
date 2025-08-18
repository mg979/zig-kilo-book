# The statusline

Uncomment the line in `refreshScreen()` where we draw the statusline.

<div class="code-title">Editor.zig: refreshScreen()</div>

```zig
    try e.drawRows();
```

<div class="code-diff-removed">

```zig
    // try e.drawStatusline();
```
</div>

<div class="code-diff-added-top">

```zig
    try e.drawStatusline();
```
</div>

### The `drawStatusline()` function

I put this below `drawRows()`:

<div class="code-title">Editor.zig</div>

```zig
/// Append the statusline to the surface.
fn drawStatusline(e: *Editor) !void {
    const V = &e.view;
    // code to come...
}
```

We want the color of the statusline to be the inverse of the normal text color,
with dark text over bright background.
We want two sections, so we declare two buffers.

<div class="code-title">Editor.zig: drawStatusline()</div>

```zig
    try e.toSurface(ansi.ReverseColors);

    var lbuf: [200]u8 = undefined;
    var rbuf: [80]u8 = undefined;
```

- on the **left side** we want to display the filename, or `[No Name]` for a newly
created file, and the _modified_ state of the buffer

- on the **right side**, the filetype (or `no ft`) and the current cursor position

<div class="code-title">Editor.zig: drawStatusline()</div>

```zig
    // left side of the statusline
    var ls = std.fmt.bufPrint(&lbuf, "{s} - {} lines{s}", .{
        e.buffer.filename orelse "[No Name]",
        e.buffer.rows.items.len,
        if (e.buffer.dirty) " [modified]" else "",
    }) catch "";

    // right side of the statusline (leading space to guarantee separation)
    var rs = std.fmt.bufPrint(&rbuf, " | {s} | col {}, ln {}/{} ", .{
        e.buffer.syntax orelse "no ft",
        V.cx + 1,
        V.cy + 1,
        e.buffer.rows.items.len,
    }) catch "";
```

We'll use `std.fmt.bufPrint` to format the two sides of the statusline, then
we'll fill with spaces the room between them, to cover the whole
`e.screen.cols` dimension, which would be the width of the screen.

Note that we use the `orelse` statement to provide fallbacks for our optional
variables (`e.buffer.filename` and `e.buffer.syntax`)

Since we'll use fixed buffers on the stack for `bufPrint`, there's the risk of
having filenames that are so long that they won't fit, in that case we just
print nothing. We do the same for the right side.

We'll prioritize the left side, in case there isn't enough room for both.

We'll have to ensure we reset colors and insert a new line at the end. We could
use a `defer` statement for this purpose, but inside `defer` statements error
handling isn't allowed, so we would have to ignore the errors, and hope for the
best. Instead we'll create a small helper function so that errors can still be
handled. In Zig the `goto` statement doesn't exist, so we must get used to this
kind of alternatives.

<div class="code-title">Editor.zig: drawStatusline()</div>

```zig
    var room_left = e.screen.cols;

    // prioritize left side
    if (ls.len > room_left) {
        ls = ls[0 .. room_left];
    }
    room_left -= ls.len;

    try e.toSurface(ls);

    if (room_left == 0) {
        try e.finalizeStatusline();
        return;
    }
```

```admonish note title="Labeled blocks as goto alternative" collapsible=true
Another alternative to `goto` is a labeled block, for example:

<pre class="code-block-small"><code class="language-zig">do: {
    std.debug.print("do block\n", .{});

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        if (i == 5) {
            break :do;
        }
    }
    std.debug.print("no break\n", .{});
}
std.debug.print("exit\n", .{});
</code></pre>

prints:

<pre class="code-block-small"><code class="language-zig">do block
exit
</code></pre>

This increases the indentation level of the whole block, though, so I prefer
other solutions, when possible.
```

To make sure we only append if there's enough room, we track the available room
in the `room_left` variable that is initially equal to `e.screen.cols`, and we
reduce it as we determine the size of the left and right sides

Append the right side and we're done:

<div class="code-title">Editor.zig: drawStatusline()</div>

```zig
    // add right side and spaces if there is room left for them
    if (rs.len > room_left) {
        rs = rs[0 .. room_left];
    }
    room_left -= rs.len;

    try e.surface.appendNTimes(e.alc, ' ', room_left);
    try e.toSurface(rs);
    try e.finalizeStatusline();
```

### `finalizeStatusline()`

This is the helper function to finalize the statusline, and still be able to
handle errors.

<div class="code-title">Editor.zig</div>

```zig
/// Reset colors and append new line after statusline
fn finalizeStatusline(e: *Editor) !void {
    try e.toSurface(ansi.ResetColors);
    try e.toSurface("\r\n");
}
```

Compile and run, and enjoy your statusline!
