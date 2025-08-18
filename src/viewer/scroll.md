# Scroll the view

There's one more thing to write, before all this begins to actually work. Until
now, movement keys would set the row (`View.cy`) and the real column (`View.cx`).
But in our `refreshScreen()` function, the escape sequence that actually moves
the cursor to the new position will need `View.rx`, that is the column in the
rendered row.

This value will be set in another function, `scroll()`, which will be invoked
at the top of the `refreshScreen()` function. So place the call now:

<div class="code-diff-added">

```zig
/// Full refresh of the screen.
fn refreshScreen(e: *Editor) !void {
```
</div>

```zig
    e.scroll();
```

We must define another option:

<div class="code-title">option.zig</div>

```zig
/// Minimal number of screen lines to keep above and below the cursor
pub var scroll_off: u8 = 2;
```

The actual `scroll()` function has 3 purposes:

- adapt the view to respect the `scroll_off` option
- set the visual column (column in the rendered row)
- set `View.rowoff` and `View.coloff`, which control the visible part of the
buffer relatively to the first row and the first column

<div class="code-title">Editor.zig</div>

```zig
/// Scroll the view, respecting scroll_off.
fn scroll(e: *Editor) void {
    const V = &e.view;
    const numrows = e.buffer.rows.items.len;

    // handle scroll_off here...

    // update rendered column here...

    // update rowoff and coloff here...
}
```

### the `scroll_off` option

This is how the Vim documentation describes it:

_Minimal number of screen lines to keep above and below the cursor.
This will make some context visible around where you are working._

```zig
    //////////////////////////////////////////
    //          scrolloff option
    //////////////////////////////////////////

    if (opt.scroll_off > 0 and numrows > e.screen.rows) {
        while (V.rowoff + e.screen.rows < numrows
               and V.cy + opt.scroll_off >= e.screen.rows + V.rowoff)
        {
            V.rowoff += 1;
        }
        while (V.rowoff > 0 and V.rowoff + opt.scroll_off > V.cy) {
            V.rowoff -= 1;
        }
    }
```

### The rendered column

```zig
    //////////////////////////////////////////
    //          update rendered column
    //////////////////////////////////////////

    V.rx = 0;

    if (V.cy < numrows) {
        V.rx = e.currentRow().cxToRx(V.cx);
    }
```

We just use the `cxToRx()` function, for all lines except the last one, which
is completely empty, not even a `\n` character, so we can't index it in any
way (the program would panic).

### `rowoff`, `coloff`

`rowoff` is the topmost visible row, `coloff` is the leftmost visible column.
While the latter is rarely positive, the former will be positive whenever we
can't see the first line of the file.

When the function is called, `cy` (the cursor column) can have a new value, but
`rowoff` has still the old value, so it must be updated. Same for `coloff`.

```zig
    //////////////////////////////////////////
    //      update rowoff and coloff
    //////////////////////////////////////////

    // cursor has moved above the visible window
    if (V.cy < V.rowoff) {
        V.rowoff = V.cy;
    }
    // cursor has moved below the visible window
    if (V.cy >= V.rowoff + e.screen.rows) {
        V.rowoff = V.cy - e.screen.rows + 1;
    }
    // cursor has moved beyond the left edge of the window
    if (V.rx < V.coloff) {
        V.coloff = V.rx;
    }
    // cursor has moved beyond the right edge of the window
    if (V.rx >= V.coloff + e.screen.cols) {
        V.coloff = V.rx - e.screen.cols + 1;
    }
```

```admonish important title="Casting numbers" collapsible=true
When calculating a value, and we are handling **unsigned** integer types (like
in this case), we should avoid subtractions, unless we are **absolutely** sure
that the left operand is greater than the right operand.

Castings in Zig tend to be quite verbose, since the Zig phylosophy is to make
everything as explicit as possible, and the verbosity is also an element of the
concept of _friction_ that Zig has adopted: to make safe things easy, and
unsafe things uncomfortable, even if not impossible, so that one becomes
inclined to take the safer route to the solution of a problem.

In this program, we don't do any casting, but we don't have to deal with
floating point numbers either.

To avoid castings of unsigned integers, sometimes it's enough to move the
subtracted operand to the other side of the equation, making it become
a positive operand. It's what we're doing here, even though it can make the
operation less intuitive.

This [thread on Ziggit
forum](https://ziggit.dev/t/short-math-notation-casting-clarity-of-math-expressions/10008)
is an interesting read about castings.
```

### Compile and run!

Our text viewer is complete. You should be able to open any file and navigate
it with ease.
