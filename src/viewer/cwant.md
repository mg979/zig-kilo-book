# Handling the wanted column

When we move vertically, the cursor keeps its current column. That's pretty
obvious. But when it moves to a shorter line, if we don't keep track of the
previous value, it will keep moving along the shorter line, instead we want to
move along the same column from where we started. That is the _wanted column_,
and in our `View` type is the `cwant` field.

This variable should be:

- restored when moving vertically, either with arrow keys or by page

- set to the current column when moving left or right, or to the beginning of
the line (<kbd>Home</kbd> key), or after typing/deleting something

- when using the <kbd>End</kbd> key, it should be set to a special value that
means: always stick to the end of the line when moving vertically

The special value we use is `std.math.maxInt(usize)`, which we store in
a constant:

<div class="code-title">Editor.zig</div>

```zig
const maxUsize = std.math.maxInt(usize);
```

### The Cwant enum

These different behaviors are listed in an `enum`, which will go in our `types`
module:

<div class="code-title">types.zig</div>

```zig
/// Controls handling of the wanted column.
pub const Cwant = enum(u8) {
    /// To set cwant to a new value
    set,
    /// To restore current cwant, or to the last column if too big
    restore,
    /// To set cwant to maxUsize, which means 'always the last column'
    maxcol,
};
```

### The `doCwant()` function

Differently from the original `kilo` editor, here the `cwant` field will track
the _rendered_ column, not the real one, which makes more sense in an editor.

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              View operations
//
///////////////////////////////////////////////////////////////////////////////

/// Handle wanted column. `want` can be:
/// .set: set e.view.cwant to a new value
/// .maxcol: set to maxUsize, which means 'always the last column'
/// .restore: set current column to cwant, or to the last column if too big
fn doCwant(e: *Editor, want: t.Cwant) void {
    const V = &e.view;
    const numrows = e.buffer.rows.items.len;

    switch (want) {
        // code to come...
    }
}
```

So when we set `cwant`, we assign it to the current column of the _rendered_
row.

If `want` is `.maxcol`, we set `cwant` to our special value.

<div class="code-title">Editor.zig: doCwant()</div>

```zig
        .set => {
            V.cwant = if (V.cy < numrows) e.currentRow().cxToRx(V.cx) else 0;
        },
        .maxcol => {
            V.cwant = maxUsize;
        },
```

When we restore it, since `cwant` is an index in the _rendered_ row,
we use `rxToCx()` to find out the real column, to which `cx` must be set.

When we restore `cwant`, we'll check if we can actually restore it. If the
length of the current row is shorter, the cursor will be moved to the last
column.

If the value of `cwant` is our special value, the cursor will always be placed
in the last column, even if the starting line was shorter than the following
ones.

<div class="code-title">Editor.zig: doCwant()</div>

```zig
        .restore => {
            if (V.cy == numrows) { // past end of file
                V.cx = 0;
            }
            else if (V.cwant == maxUsize) { // wants end of line
                V.cx = e.currentRow().clen();
            }
            else {
                const row = e.currentRow();
                const rowlen = row.clen();
                if (rowlen == 0) {
                    V.cx = 0;
                }
                else {
                    // cwant is an index of the rendered column, must convert
                    V.cx = row.rxToCx(V.cwant);
                    if (V.cx > rowlen) {
                        V.cx = rowlen;
                    }
                }
            }
        },
```

```admonish note
Here the `else` prong isn't needed, since we handle all members of the `enum`.
```

### Calls to `doCwant()`

Where should the wanted column be handled? Right in the `processKeypress()`
function. You'll have to add calls to `doCwant()` as follows:

<div class="code-title">Editor.zig: somewhere in processKeypress()</div>

```zig
            // after handling <ctrl-d>, <ctrl-u>, <page-up>, <page-down>
            e.doCwant(.restore);

            // after handling <up>, <down>
            e.doCwant(.restore);

            // after handling <left>, <right> and <home>
            e.doCwant(.set);

            // after handling <end>
            e.doCwant(.maxcol);
```
