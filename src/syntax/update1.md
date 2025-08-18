# Doing the highlight

First, let's add a new option, which controls globally if syntax highlighting
should be done or not:

<div class="code-title">option.zig</div>

```zig
/// Enable syntax highlighting
pub var syntax = true;
```

In `updateHighlight`, we'll return early if the buffer has no filetype, or this
option is disabled.

<div class="code-title">Editor.zig: updateHighlight()</div>

```zig
    // reset the row highlight to normal
    row.hl = try e.alc.realloc(row.hl, row.render.len);
    @memset(row.hl, .normal);
```

<div class="code-diff-added-top">

```zig
    if (e.buffer.syntax == null or opt.syntax == false) {
        return;
    }
```
</div>

We do the highlight of the whole rendered row. This is certainly not ideal,
because certain files have very long lines, and only a part of it is actually
visible. At the same time, if we restrict parsing to only what we can see, we
will certainly have bad highlight in all those cases where the highlight of
a character depends on what precedes it, or even follows.

We could try to do it anyway and add some safety margin, both on the left and
the right side of the rendered part of the line, so that parsing starts before
`coloff` and ends after `coloff + screen.cols`, but it wouldn't be perfect
(think of very long line comments).

We could make it optional, to have a _fast highlight mode_, but we can't change
options inside the editor.

Doing it properly would need some serious changes, but we'll pass this time.
I said it is a toy editor for reasons, and this isn't the only one.
