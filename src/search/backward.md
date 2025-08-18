# Search backward

The process is very similar, but in reverse. This time we use the
`std.mem.lastIndexOf` function, that finds the relative position of a slice in
another slice _before a certain index_, or returns `null` if the slice isn't
contained in the other slice.

Following steps are followed unless a match is returned.

<div class="numbered-table">

| | |
|-|-|
| • | search a slice of the current row `[0..col]` |
| • | search the previous lines |
| • | start of file, no wrapscan? return null |
| • | restart from the end of the file |
| • | if you reach the initial line, only search `[col..]` |
</div>

If a match is found, `pos.lnr` is updated, because the callback will need the
line where it was found.

<div class="code-title">Editor.zig</div>

```zig
/// Start a search backwards.
fn findBackward(e: *Editor, query: []const u8, pos: *t.Pos) ?[]const u8 {
    // first line, search up to col
    const row = e.rowAt(pos.lnr);
    const col = pos.col;
    var rowchars = row.chars.items;
    var i: usize = undefined;

    if (lastIndexOf(u8, rowchars[0..col], query)) |m| {
        return rowchars[m .. m + query.len];
    }
    else if (pos.lnr > 0) {
        // previous lines, search full line
        i = pos.lnr - 1;
        while (true) : (i -= 1) {
            rowchars = e.rowAt(i).chars.items;

            if (lastIndexOf(u8, rowchars, query)) |m| {
                pos.lnr = i;
                return rowchars[m .. m + query.len];
            }
            if (i == 0) break;
        }
    }

    if (!opt.wrapscan) {
        return null;
    }

    i = e.buffer.rows.items.len - 1;
    while (i > pos.lnr) : (i -= 1) {
        rowchars = e.rowAt(i).chars.items;

        if (lastIndexOf(u8, rowchars, query)) |m| {
            pos.lnr = i;
            return rowchars[m .. m + query.len];
        }
    }

    // check again the starting line, this time in the part after the offset
    rowchars = e.rowAt(pos.lnr).chars.items;

    if (lastIndexOf(u8, rowchars[col..], query)) |m| {
        // m is the index in the substring starting from `col`, therefore we
        // must add `col` to get the real index in the row
        return rowchars[m + col .. m + col + query.len];
    }
    return null;
}
```
