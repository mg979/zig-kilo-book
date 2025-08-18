Before we deal with movements, we must complete our Row type.

### The `rxToCx()` method

This does the opposite of the `cxToRx()` method, that is, it finds the real
column for an index of the rendered row. It must still iterate the real row,
not the rendered one, because from the latter we just couldn't know what was
a `tab` and what a real `space` character. Therefore we iterate the real row
like in `cxToRx()`, we track both the rendered column and the current index in
the real row, and when the resulting rendered column is greater than the
requested column we return the current index in the real row.

<div class="code-title">Row.zig</div>

```zig
/// Calculate the position of a rendered column in the real row.
pub fn rxToCx(row: *Row, rx: usize) usize {
    var cur_rx: usize = 0;
    var cx: usize = 0;
    while (cx < row.chars.items.len) : (cx += 1) {
        if (row.chars.items[cx] == '\t') {
            cur_rx += (opt.tabstop - 1) - (cur_rx % opt.tabstop);
        }
        cur_rx += 1;

        if (cur_rx > rx) {
            return cx;
        }
    }
    return cx;
}
```
