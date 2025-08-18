# Insert characters

Before inserting a character, we check if we are in a new row, if so, we insert
the row in the buffer. After that, we can just insert the character and move
forward. We wrote already our `insertRow()` function, so there's nothing to add
(for now).

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              In-row operations
//
///////////////////////////////////////////////////////////////////////////////

/// Insert a character at current cursor position. Handle textwidth.
fn insertChar(e: *Editor, c: u8) !void {
    const V = &e.view;

    // last row, insert a new row before inserting the character
    if (V.cy == e.buffer.rows.items.len) {
        try e.insertRow(e.buffer.rows.items.len, "");
    }

    // insert the character and move the cursor forward
    try e.rowInsertChar(V.cy, V.cx, c);
    V.cx += 1;
}
```

### `rowInsertChar()`

This will perform the actual character insertion in the `row.chars` ArrayList,
update the rendered row, and set the _modified_ flag.

<div class="code-title">Editor.zig</div>

```zig
/// Insert character `c` in the row with index `ix`, at column `at`.
fn rowInsertChar(e: *Editor, ix: usize, at: usize, c: u8) !void {
    try e.rowAt(ix).chars.insert(e.buffer.alc, at, c);
    try e.updateRow(ix);
    e.buffer.dirty = true;
}
```
