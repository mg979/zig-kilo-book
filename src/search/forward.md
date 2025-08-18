# Search forwards

When searching forwards for a match, we start searching at the given position,
in the current row. We use the `std.mem.indexOf` function, that finds the
relative position of a slice in another slice, or returns `null` if the slice
isn't contained in the other slice.

Following steps are followed unless a match is returned.

<div class="numbered-table">

| | |
|-|-|
| • | search a slice of the current row `[col..]` |
| • | reset search column to 0 |
| • | search the following lines |
| • | end of file, no wrapscan? return null |
| • | restart from the beginning of the file |
| • | if you reach the initial line, only search `[..col]` |
</div>

If a match is found, `pos.lnr` is updated, because the callback will need the
line where it was found.

<div class="code-title">Editor.zig</div>

```zig
/// Start a search forwards.
fn findForward(e: *Editor, query: []const u8, pos: *t.Pos) ?[]const u8 {
    var col = pos.col;
    var i = pos.lnr;

    while (i < e.buffer.rows.items.len) : (i += 1) {
        const rowchars = e.rowAt(i).chars.items;

        if (indexOf(u8, rowchars[col..], query)) |m| {
            pos.lnr = i;
            return rowchars[(col + m)..(col + m + query.len)];
        }

        col = 0; // reset search column
    }

    if (!opt.wrapscan) {
        return null;
    }

    // wrapscan enabled, search from start of the file to current row
    i = 0;
    while (i <= pos.lnr) : (i += 1) {
        const rowchars = e.rowAt(i).chars.items;

        if (indexOf(u8, rowchars, query)) |m| {
            pos.lnr = i;
            return rowchars[m .. m + query.len];
        }
    }
    return null;
}
```
