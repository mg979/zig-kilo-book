# Inserting a row

If you remember, our `Row` type had two arrays:

<div class="code-title">Row.zig</div>

```zig
/// The ArrayList with the actual row characters
chars: t.Chars,

/// Array with the visual representation of the row
render: []u8,
```

where `Chars` is actually a `std.ArrayList(u8)`, which we'll be using a lot.

In our `insertRow()` function, what we'll do is:

- initialize a new `Row`
- copy the line into `row.chars`
- insert the row in `Buffer.rows`

Finally we'll update the row, and set the `dirty` flag.

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Row operations
//
///////////////////////////////////////////////////////////////////////////////

/// Insert a row at index `ix` with content `line`, then update it.
fn insertRow(e: *Editor, ix: usize, line: []const u8) !void {
    const B = &e.buffer;

    var row = try t.Row.init(B.alc);
    try row.chars.appendSlice(B.alc, line);

    try B.rows.insert(B.alc, ix, row);

    try e.updateRow(ix);
    B.dirty = true;
}
```

We set the _dirty_ flag because the same function will be used while modifying
the buffer, but for now we're just reading the file. This flag will be reset in
`openFile()`.

Add this at the bottom of `openFile()`:

<div class="code-title">Editor.zig: openFile()</div>

```zig
    else |err| switch (err) {
        error.FileNotFound => {}, // new unsaved file
        else => return err,
    }
```

<div class="code-diff-added-top">

```zig
    B.dirty = false;
```
</div>

```zig
}
```
