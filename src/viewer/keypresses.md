# More keypress handling

Inside the switch that handles keypresses, we add a variable and more prongs:

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
    const B = &e.buffer;
```

<div class="code-diff-added-top">

```zig
    const V = &e.view;
```
</div>

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
        .ctrl_d, .ctrl_u, .page_up, .page_down => {
            // by how many rows we'll jump
            const leap = e.screen.rows - 1;

            // place the cursor at the top of the window, then jump
            if (k == .ctrl_u or k == .page_up) {
                V.cy = V.rowoff;
                V.cy -= @min(V.cy, leap);
            }
            // place the cursor at the bottom of the window, then jump
            else {
                V.cy = V.rowoff + e.screen.rows - 1;
                V.cy = @min(V.cy + leap, B.rows.items.len);
            }
        },

        .home => {
            V.cx = 0;
        },

        .end => {
            // last row doesn't have characters!
            if (V.cy < B.rows.items.len) {
                V.cx = B.rows.items[V.cy].clen();
            }
        },

        .left, .right => {
            e.moveCursorWithKey(k);
        },

        .up, .down => {
            e.moveCursorWithKey(k);
        },
```

I added comments so that what happens should be self-explanatory.

One of my favorite Zig features is how you can omit the enum type when using
their values, since the type of those values is known to be that type of enum.
It makes the code very expressive and avoids redundancy, without resorting to
macros or untyped constants. It also makes it easier to write this kind of
guides.

We see the a new function, `moveCursorWithKey()`, which we'll cover next.
