# Updating a row

Updating the row means that we must update the `render` field from the `chars`
field. That is, we must generate what will be actually rendered on screen.

The only way they will differ, at this point, is given by the possible presence
of tab characters in our `chars` ArrayList.

Let's say we want to make this `tabstop` an option, so that it can be
configured. We create a `src/option.zig` file and paste the following:

<div class="code-title">option.zig</div>

```zig
//! Editor options. For now they are hard-coded and cannot be modified from
//! inside the editor, neither are read from a configuration file.

/// Number of spaces a tab character accounts for
pub var tabstop: u8 = 8;
```

As the description says, they're hard coded, but we'll still use a module, so
that we can test different options ourselves if we want.

We'll also have to import it in the Constants section:

<div class="code-title">Editor.zig</div>

```zig
const opt = @import("option.zig");
```

### rowAt() and currentRow()

We'll write other helper functions that we'll use a lot:

<div class="code-title">Editor.zig</div>

```zig
/// Get the row pointer at index `ix`.
fn rowAt(e: *Editor, ix: usize) *t.Row {
    return &e.buffer.rows.items[ix];
}

/// Get the row pointer at cursor position.
fn currentRow(e: *Editor) *t.Row {
    return &e.buffer.rows.items[e.view.cy];
}
```

Because frankly, to take that pointer all the times becomes annoying after
a while.

We shouldn't worry about performance loss for too many function calls: Zig
lacks macros, so the compiler tries to inline small functions when it can.
Writing small functions is actually the Zig way to write macros.

### updateRow()

The purpose of this function is to update the _rendered_ row, which is what we
see on screen.

<div class="code-title">Editor.zig</div>

```zig
/// Update row.render, that is the visual representation of the row.
/// Performs a syntax update at the end.
fn updateRow(e: *Editor, ix: usize) !void {
    // code to come...
}
```

### Allocator.realloc()

<div class="code-title">Editor.zig: updateRow()</div>

```zig
    const row = e.rowAt(ix);

    // get the length of the rendered row and reallocate
    const rlen = // ??? total size of the rendered row ???
    row.render = try e.alc.realloc(row.render, rlen);
```

As explained before, I chose to make `row.render` a simple array because we can
desume its size before any reallocation happens. Most of the time
a reallocation would not result in a new allocation, because `realloc()` does
the following:

- if the previous size is 0 (first time the row is updated) and new size is
bigger, there is an allocation
- if the new size is smaller (characters are deleted), it is resized
- if the new size is slightly bigger (such as when inserting a single
character while typing), most of the times it will extend the array without
reallocating
- it would only allocate when the size is bigger and it's not possible to
extend the array

An ArrayList would bring some benefits, but also increase total memory usage.
For now we'll keep it simple, but we'll keep it in mind.

### Looping characters of the real row

<div class="code-title">Editor.zig: updateRow()</div>

```zig
    var idx: usize = 0;
    var i: usize = 0;

    while (i < row.chars.items.len) : (i += 1) {
        if (row.chars.items[i] == '\t') {
            row.render[idx] = ' ';
            idx += 1;
            while (idx % opt.tabstop != 0) : (idx += 1) {
                row.render[idx] = ' ';
            }
        }
        else {
            row.render[idx] = row.chars.items[i];
            idx += 1;
        }
    }
```

What the loop does, is that it inserts in `row.render` the same character when
it's not a tab, otherwise it will convert it to spaces, making some
considerations in the process:

- inside the loop, `idx` is the current column in the rendered row
- we want a minimum of one space, so we add it, and increase `idx`
- we want to see if there are more spaces to add, and this is true if `(idx
% tabstop != 0)`

For example, assuming `tabstop = 8`, at the start of a line, where `idx` is 0,
a <kbd>Tab</kbd> would insert 8 spaces.

But a <kbd>Tab</kbd> typed in the middle of a row won't add necessarily
`tabstop` spaces, because the starting column in the rendered row may be such
that `idx % 8` is greater than 1, so if we insert a tab at `idx = 12`, we have
a space insertion, which makes `idx = 13`, then 5 more spaces, because `13
% 8 = 5`.

### Computing beforehand the size of the rendered row

```zig
    // get the length of the rendered row and reallocate
    const rlen = // ??? total size of the rendered row ???
    row.render = try e.alc.realloc(row.render, rlen);
```

We didn't assign anything to `rlen`. How do we know how long will be our
rendered row? We'll have do something similar to what we do inside the loop in
`updateRow()`, but we just increase `idx` and return the final value. But often
in our program we'll have to convert a real column index to an index in the
rendered row, so we write a function that does that.

We call the function `cxToRx()` and the call becomes:

<div class="code-diff-removed">

```zig
    const rlen = // ??? total size of the rendered row ???
```
</div>

```zig
    const rlen = row.cxToRx(row.chars.items.len);
```

That is, we calculate the index in the rendered row for the last column of the
real row.

We put this function in `Row.zig`, because it is in agreement with how we
wanted to design our types: they shouldn't change the state of the Editor, but
they can return their own state. Here Row will not modify itself, so it's ok.

<div class="code-title">Row.zig: methods section</div>

```zig
/// Calculate the position of a real column in the rendered row.
pub fn cxToRx(row: *Row, cx: usize) usize {
    var rx: usize = 0;
    for (0..cx) |i| {
        if (row.chars.items[i] == '\t') {
            rx += (opt.tabstop - 1) - (rx % opt.tabstop);
        }
        rx += 1;
    }
    return rx;
}
```

The loop is a bit different here, because instead of two nested loops we have
only one. That's because we don't need to modify the row in any way, so we can
calculate the needed spaces in a single operation. Which is quite a bit more
difficult to understand, to be honest. Feel free to recreate an example loop
step by step as we did above.

Also this function needs to import `option.zig`, so do that.

```admonish note
We don't handle multi-byte characters, and we don't have virtual text of any
kind. In a real editor this function would be more complex.
```
