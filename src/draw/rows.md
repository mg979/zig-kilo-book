# Drawing the rows

This function will be expanded later, but for now all it needs to do is to draw
the rows without any highlight.

<div class="code-title">Editor.zig</div>

```zig
/// Append rows to be drawn to the surface. Handles escape sequences for syntax
/// highlighting.
fn drawRows(e: *Editor) !void {
    // code to come...
}
```

We can print a number of rows which is equal to the height of our main window,
which is `e.screen.rows`. We use a `for` loop with a range, but to the index
`y` we must add `e.view.rowoff`, which is the current row offset. This will be
greater than `0` if we scroll down our window and the first row went
off-screen.

<div class="code-title">Editor.zig: drawRows()</div>

```zig
    const V = &e.view;
    const rows = e.buffer.rows.items;

    for (0 .. e.screen.rows) |y| {
        const ix: usize = y + V.rowoff;
```

Since we draw by screen rows, and not by Buffer rows, `y` may be greater than
the number of the Buffer rows, which means we are past the end of the file. In
this case we draw a `~` to point that out.

<div class="code-title">Editor.zig: drawRows()</div>

```zig
        // past buffer content
        if (ix >= rows.len) {
            try e.toSurface('~');
        }
```

Otherwise, we are within the file content, but it doesn't mean that there is
something to print in all cases:

<div class="code-title">Editor.zig: drawRows()</div>

```zig
        // within buffer content
        else {
            // length of the rendered line
            const rowlen = rows[ix].render.len;

            // actual length that should be drawn because visible
            var len = if (V.coloff > rowlen) 0 else rowlen - V.coloff;
```

For example, if we scrolled the window to the right, the leftmost columns would
go off-screen, and `e.view.coloff` would become positive. If the line is
shorter than that, nothing will be printed, because it's completely off-screen.

We also limit `len` to the number of screen columns:

<div class="code-title">Editor.zig: drawRows()</div>

```zig
            len = @min(len, e.screen.cols);
```

If `len > 0` there's something to print: which would be the slice of the
rendered line that starts at `coloff`, and is long `len` characters.

We append this slice to the surface ArrayList.


<div class="code-title">Editor.zig: drawRows()</div>

```zig
            // draw the visible part of the row
            if (len > 0) {
                try e.toSurface(rows[ix].render[V.coloff .. V.coloff + len]);
            }
        }
```

We end the line after that:

<div class="code-title">Editor.zig: drawRows()</div>

```zig
        try e.toSurface(ansi.ClearLine);
        try e.toSurface("\r\n"); // end the line
    }
```

Again: `V.coloff` is `0` unless a part of the row went off-screen on the left
side.

At this point, if you compile and run:

    ./kilo kilo

you should already be able to visualize the file on the screen! That's big
progress. You can't move the cursor, and you can still quit the editor with
<kbd>Ctrl-Q</kbd> pressed 3 times.

```admonish note
You will notice that the last 2 lines of the screen don't have the `~`
character: that's because in `init()` we subtracted 2 from the real screen
height, to make room for statusline and message area.
```
