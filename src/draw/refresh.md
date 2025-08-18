# Refresh the screen

In `startUp()`, replace the commented placeholder in the event loop:

<div class="code-title">Editor.zig: startUp()</div>

```zig
    while (e.should_quit == false) {
```

<div class="code-diff-removed">

```zig
        // refresh the screen
```
</div>

<div class="code-diff-added-top">

```zig
        try e.refreshScreen();
```
</div>

We'll do the drawing with this function, that goes in a new section, which
I put above the Helpers section:

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Screen update
//
///////////////////////////////////////////////////////////////////////////////

/// Full refresh of the screen.
fn refreshScreen(e: *Editor) !void {
    // code to come...
}
```

We'll have to explain what goes on.

- we clear our ArrayList, which will eventually contain the characters that
must be printed

- we set the background color, hide the terminal cursor so that it doesn't get
in the way, and move the cursor to the top left position

- we draw the rows, later we'll also draw the statusline and the message area

<div class="code-title">Editor.zig: refreshScreen()</div>

```zig
    e.surface.clearRetainingCapacity();

    try e.toSurface(ansi.BgDefault);
    try e.toSurface(ansi.HideCursor);
    try e.toSurface(ansi.CursorTopLeft);

    try e.drawRows();
    // try e.drawStatusline();
    // try e.drawMessageBar();
```

- we move the cursor to its current position and we show it again

- we print the whole thing with a `write()` call

<div class="code-title">Editor.zig: refreshScreen()</div>

```zig
    const V = &e.view;

    // move cursor to its current position (could have been moved with keys)
    var buf: [32]u8 = undefined;
    const row = V.cy - V.rowoff + 1;
    const col = V.rx - V.coloff + 1;
    try e.toSurface(try ansi.moveCursorTo(&buf, row, col));
    try e.toSurface(ansi.ShowCursor);

    try linux.write(e.surface.items);
```

### `moveCursorTo()`

To move the cursor we'll need a new function in `ansi.zig`:

<div class="code-title">ansi.zig</div>

```zig
/// Return the escape sequence to move the cursor to a position.
pub fn moveCursorTo(buf: []u8, row: usize, col: usize) ![]const u8 {
    return std.fmt.bufPrint(buf, CSI ++ "{};{}H", .{ row, col });
}
```

It takes a slice `buf` and formats it to generate an escape sequence that will
move the cursor to a position.
