# Move with keys

This function will let us move the cursor with arrow keys. Also in this case
the code is self-explanatory.

With keys <kbd>Left</kbd> and <kbd>Right</kbd> we can also change row, if we
are respectively in the first or last column of the row.

<div class="code-title">Editor.zig</div>

```zig
/// Update the cursor position after a key has been pressed.
fn moveCursorWithKey(e: *Editor, key: t.Key) void {
    const V = &e.view;
    const numrows = e.buffer.rows.items.len;

    switch (key) {
        .left => {
            if (V.cx != 0) { // not the first column
                V.cx -= 1;
            }
            else if (V.cy > 0) { // move back to the previous row
                V.cy -= 1;
                V.cx = e.currentRow().clen();
            }
        },
        .right => {
            if (V.cy < numrows) {
                if (V.cx < e.currentRow().clen()) { // not the last column
                    V.cx += 1;
                }
                else { // move to the next row
                    V.cy += 1;
                    V.cx = 0;
                }
            }
        },
        .up => {
            if (V.cy != 0) {
                V.cy -= 1;
            }
        },
        .down => {
            if (V.cy < numrows) {
                V.cy += 1;
            }
        },
        else => {},
    }
}
```
