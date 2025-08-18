# Insert a new line

We insert a new line when we press <kbd>Enter</kbd>. Nothing simpler right?
This operation is a bit more complex than it seems, especially if we want to
copy indentation, which is optional, but it's so useful that we don't want to
miss it.

Let's ignore indentation for now, and write the basic function.

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Insert lines
//
///////////////////////////////////////////////////////////////////////////////

/// Insert a new line at cursor position. Will carry to the next line
/// everything that is after the cursor.
fn insertNewLine(e: *Editor) !void {
    const V = &e.view;

    // make sure the beginning of the line is visible
    V.coloff = 0;

    // code to come...

    // row operations have been concluded, update rows
    try e.updateRow(V.cy - 1);
    try e.updateRow(V.cy);

    // set cursor position at the start of the new line
    V.cx = 0;
    V.cwant = 0;
}
```

At least, we want to handle several cases:

- are we at the beginning of the line (`cx = 0`)? We insert an empty line
above the current line, then increase the row number

<div class="code-title">Editor.zig: insertNewLine()</div>

```zig
    // at first column, just insert an empty line above the cursor
    if (V.cx == 0) {
        try e.insertRow(V.cy, "");
        V.cy += 1;
        return;
    }
```

- is there any whitespace that follows the cursor? Then we want to remove it
when carrying over the text that follows

<div class="code-title">Editor.zig: insertNewLine()</div>

```zig
    // leading whitespace removed from characters after cursor
    var skipw: usize = 0;

    var oldrow = e.currentRow().chars.items;

    // any whitespace before the text that is going into the new row
    if (V.cx < oldrow.len) {
        skipw = str.leadingWhitespaces(oldrow[V.cx..]);
    }
```

We already know that we are in the middle of a line, so we must carry
everything that comes after the cursor to the new line.

After the row has been inserted, we proceed to the new row and shrink the row
above. We perform this operation last, because we needed those characters to be
able to append them. _Cut and paste_ is actually a _copy then delete_ operation
in our case.

<div class="code-title">Editor.zig: insertNewLine()</div>

```zig
    // will insert a row with the characters to the right of the cursor
    // skipping whitespace after the cursor
    try e.insertRow(V.cy + 1, oldrow[V.cx + skipw ..]);

    // proceed to the new row
    V.cy += 1;

    // delete from the row above the content that we moved to the next row
    e.rowAt(V.cy - 1).chars.shrinkAndFree(e.alc, V.cx);
```

```admonish note
We are using the `shrinkAndFree` method, which is not optimal, because in many
cases we would like to retain the ArrayList capacity. At least partially.

We could use instead the method `shrinkRetainingCapacity`, which does what it
says. But this could lead to excessive memory usage, because rows would always
keep the biggest capacity they had at any time, always growing, never
shrinking.

Maybe better would be to do a `shrinkAndFree` while keeping some
extra room, followed by a `resize` to set the correct length.

The same concepts would apply to `row.render`, if it was made an ArrayList.

These are all optimizations that can wait, anyway. For now, we keep it simple.
```

You might want to compile and run at this point, to check that everything is
working. You should be able to insert characters, delete them, and inserting
new lines.

### Autoindent

We also want an option for _autoindent_.

Let's add the option:

<div class="code-title">option.zig</div>

```zig
/// Copy indent from current line when starting a new line
pub var autoindent = true;
```

Autoindent brings additional concerns:

- we should copy the indent from the line above

- are we inserting the line while in the middle of the indent? Then we want to
  shorten the indent and remove the part of it that lies after the cursor

Add the `ind` variable: it is the number of whitespace characters that we must
copy from the line above.

<div class="code-diff-added">

```zig
    // leading whitespace removed from characters after cursor
    var skipw: usize = 0;
```
</div>

```zig
    // extra characters for indent
    var ind: usize = 0;
```

What if we hit <kbd>Enter</kbd> in the middle of the indentation? We want to
reduce it to the current column.

<div class="code-diff-added">

```zig
    // any whitespace before the text that is going into the new row
    if (V.cx < oldrow.len) {
        skipw = str.leadingWhitespaces(oldrow[V.cx..]);
    }
```
</div>

```zig
    if (opt.autoindent) {
        ind = str.leadingWhitespaces(oldrow);

        // reduce indent if current column is within it
        if (V.cx < ind) {
            ind = V.cx;
        }
    }
```

After we proceed to the new row, we must copy over the indent from the line
above. Before copying, we reassign the pointer, because a row insertion in
`Buffer.rows` has happened, which could have caused the invalidation of all row
pointers...

<div class="code-diff-added">

```zig
    // proceed to the new row
    V.cy += 1;
```
</div>

```zig
    if (ind > 0) {
        // reassign pointer, invalidated by row insertion
        oldrow = e.rowAt(V.cy - 1).chars.items;

        // in new row, shift the old content forward, to make room for indent
        const newrow = try e.currentRow().chars.addManyAt(e.alc, 0, ind);

        // Copy the indent from the previous row.
        for (0..ind) |i| {
            newrow[i] = oldrow[i];
        }
    }
```

Finally, we must update the last two lines to set the cursor column after the
indent:

<div class="code-diff-removed">

```zig
    // set cursor position at the start of the new line
    V.cx = 0;
    V.cwant = 0;
```
</div>

```zig
    // set cursor position right after the indent in the new line
    V.cx = ind;
    V.cwant = ind;
```

Compile and try it!
