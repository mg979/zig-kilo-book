# Deleting a character

By deleting a character, we mean deleting the character to the left of our
cursor, what the <kbd>Backspace</kbd> key normally does.

<div class="code-title">Editor.zig</div>

```zig
/// Delete a character before cursor position (backspace).
fn deleteChar(e: *Editor) !void {
    const V = &e.view;
    const B = &e.buffer;

    // code to come...
}
```

We'll want to handle different cases:

**Cursor is past the end of file**: move to the end of the previous line, don't
return, we will possibly delete a character.

```zig
    // past the end of the file
    if (V.cy == B.rows.items.len) {
        e.moveCursorWithKey(.left);
    }
```

**Cursor at the start of the file**: nothing to do.

```zig
    // start of file
    if (V.cx == 0 and V.cy == 0) {
        return;
    }
```

**Cursor after the first column**: delete the character at column before the
current one.

```zig
    // delete character in current line
    if (V.cx > 0) {
        try e.rowDelChar(V.cy, V.cx - 1);
        V.cx -= 1;
    }
```

**Cursor is at the start of a line which isn't the first one**: we'll append the
current line to the previous one, then delete the current row. The cursor will
then be moved to the row above, at a column that is the length of the previous
row before the lines were joined.


```zig
    // join with previous line
    else {
        V.cx = B.rows.items[V.cy - 1].clen();
        try e.rowInsertString(V.cy - 1, V.cx, e.currentRow().chars.items);
        e.deleteRow(V.cy);
        V.cy -= 1;
    }
```

### `rowDelChar()`

For the actual character deletion we write `rowDelChar()`, which closely
resembles `rowInsertChar()`:

<div class="code-title">Editor.zig</div>

```zig
/// Delete a character in the row with index `ix`, at column `at`.
fn rowDelChar(e: *Editor, ix: usize, at: usize) !void {
    _ = e.rowAt(ix).chars.orderedRemove(at);
    try e.updateRow(ix);
    e.buffer.dirty = true;
}
```

### `rowInsertString()`

In case we want to join lines, we'll need two new functions.

<div class="code-title">Editor.zig</div>

```zig
/// Insert a string at position `at`, in the row at index `ix`.
fn rowInsertString(e: *Editor, ix: usize, at: usize, chars: []const u8) !void {
    try e.rowAt(ix).chars.insertSlice(e.buffer.alc, at, chars);
    try e.updateRow(ix);
    e.buffer.dirty = true;
}
```

This is very similar to `rowInsertChar()`, but inserts a slice instead of
inserting a character. Here we're just appending at the end of the row, since
we're passing an `at` argument that is equal to the length of the row.

### `deleteRow()`

The last function we need for now is the one that deletes a row from the
Buffer. I put this function below `insertRow()`.

As mentioned when we talked about the Buffer type, we're sometimes
deinitializing individual rows in the Editor methods, which isn't ideal, but
I don't think that creating a method in Buffer just for this is that much
better. We can access the Buffer allocator just fine, but we must remember that
a Row uses the Buffer allocator, not the Editor one. It's only _happening_
right now that both Editor and Buffer use the same allocator, but things might
change in the future.

<div class="code-title">Editor.zig</div>

```zig
/// Delete a row and deinitialize it.
fn deleteRow(e: *Editor, ix: usize) void {
    var row = e.buffer.rows.orderedRemove(ix);
    row.deinit(e.buffer.alc);
    e.buffer.dirty = true;
}
```
