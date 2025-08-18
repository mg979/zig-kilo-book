# Highlight enum

We need to define the `Highlight` enum, which goes in `types`. We start with
few values and will expand it later:

<div class="code-title">types.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Highlight
//
///////////////////////////////////////////////////////////////////////////////

/// All available highlight types.
pub const Highlight = enum(u8) {
    /// The normal highlight
    normal = 0,

    /// Incremental search highlight
    incsearch,

    /// Highlight for error messages
    err,
};
```

### An array for highlight

Our Row type must have an additional array, which will have the same length
of the `render` array, and which will contain the `Highlight` for each
element of the `render` array:

<div class="code-title">Row.zig</div>

```zig
/// Array with the highlight of the rendered row
hl: []t.Highlight,
```

We'll initialize this array in `Row.init()`:

```zig
        .hl = &.{},
```

deinitialize it in `Row.deinit()`:

```zig
    allocator.free(row.hl);
```

and will fill it in a new function:

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Syntax highlighting
//
///////////////////////////////////////////////////////////////////////////////

/// Update highlight for a row.
fn updateHighlight(e: *Editor, ix: usize) !void {
    const row = e.rowAt(ix);

    // reset the row highlight to normal
    row.hl = try e.alc.realloc(row.hl, row.render.len);
    @memset(row.hl, .normal);
}
```

Later we'll do syntax highlighting here. This function is called at the end of
`updateRow()`, because every time the rendered row is updated, its highlight
must be too.

<div class="code-title">Editor.zig: updateRow()</div>
<div class="code-diff-added-top">

```zig
    try e.updateHighlight(ix);
```
</div>

    }
