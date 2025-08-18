# The `findCallback()` function

This one is big. We'll start with a stub, filled with placeholders. We reset
the highlight and we handle clean up at the start of the function, so that
later it can return at any point.


<div class="code-title">Editor.zig</div>

```zig
/// Called by promptForInput() for every valid inserted character.
/// The saved view is restored when the current query isn't found, or when
/// backspace clears the query, so that the search starts from the original
/// position.
fn findCallback(e: *Editor, ca: t.PromptCbArgs) t.EditorError!void {
    // 1. variables
    // 2. restore line highlight
    // 3. clean up
    // 4. query is empty so no need to search, but restore position
    // 5. handle backspace
    // 6. find the starting line and the column offset for the search
    // 7. start the search
}
```

### Variables

As we did before, we have a `static` struct which will save the current state
of the search.

```zig
    const static = struct {
        var found: bool = false;
        var view: t.View = .{};
        var pos: t.Pos = .{};
        var oldhl: []t.Highlight = &.{};
    };
```

We also define some constants:

```zig
    const empty = ca.input.items.len == 0;
    const numrows = e.buffer.rows.items.len;
```

### Restore line highlight before incsearch highlight

Before a new search attempt, we restore the underlying line highlight, so that
if the search fails, the search highlight has been cleared already.

```zig
    // restore line highlight before incsearch highlight, or clean up
    if (static.oldhl.len > 0) {
        @memcpy(e.rowAt(static.pos.lnr).hl, static.oldhl);
    }
```

### Clean up

The clean up must also be handled early. This block runs during the last
invocation of the callback, that is done for this exact purpose.

In this step we free the search highlight, reset our static variables and
restore the view if necessary.

```zig
    // clean up
    if (ca.final) {
        e.alc.free(static.oldhl);
        static.oldhl = &.{};
        if (empty or ca.key == .esc) {
            e.view = ca.saved;
        }
        if (!static.found and ca.key == .enter) {
            try e.statusMessage("No match found", .{});
        }
        static.found = false;
        return;
    }
```

### Empty query

This happens after we press <kbd>Backspace</kbd> and the query is now empty.
We don't cancel the search yet, but we restore the original view.
Search will be canceled if we press <kbd>Backspace</kbd> again.
We also reset `static.found` because it was true if that character we just
deleted was a match.

```zig
    // Query is empty so no need to search, but restore position
    if (empty) {
        static.found = false;
        e.view = ca.saved;
        return;
    }
```

### Handle <kbd>Backspace</kbd>

This happens when we press <kbd>Backspace</kbd>, but the query is not empty.
In this case we restore our static view, which is set later on. Note that if
the current query can't be found, this would be the same of the original view,
but what matters is that we must restore it, whatever it is.

```zig
    // when pressing backspace we restore the previously saved view
    // cursor might move or not, depending on whether there is a match at
    // cursor position
    if (ca.key == .backspace or ca.key == .ctrl_h) {
        e.view = static.view;
    }
```

### Find the starting position for the search

We define some constants, to make the function flow more understandable.

```zig
    //////////////////////////////////////////
    //   Find the starting position
    //////////////////////////////////////////

    const V = &e.view;

    const prev = ca.key == .ctrl_t;
    const next = ca.key == .ctrl_g;

    // current cursor position
    var pos = t.Pos{ .lnr = V.cy, .col = V.cx };

    const eof = V.cy == numrows;
    const last_char_in_row = !eof and V.rx == e.currentRow().render.len;
    const last_row = V.cy == numrows - 1;

    // must move the cursor forward before searching when we don't want to
    // match at cursor position
    const step_fwd = ca.key != .backspace and (next or empty or !static.found);
```

```admonish warning
If we skip the `!eof` check when defining `last_char_in_row`, we would cause
panic when starting a search at the end of the file. This happens because
`e.currentRow()` tries to get a pointer to a line that doesn't exist. Watch out
for these things!
```

We are determining where the search must start, and that's either at cursor
position, or just after that (one character to the right). That is, we must
decide whether to accept a match at cursor position or not.

When we press <kbd>Backspace</kbd>, we never want to do that.

Otherwise, want to step forward:

- if we press <kbd>Ctrl-G</kbd>, looking for the next match

- if we are at the starting position, because either:
  - we just started a search
  - query is empty
  - a match hasn't been found

In any of these cases:

```zig
    if (step_fwd) {
        if (eof or (last_row and last_char_in_row)) {
            if (!opt.wrapscan) { // restart from the beginning of the file?
                return;
            }
        }
        else if (last_char_in_row) { // start searching from next line
            pos.lnr = V.cy + 1;
        }
        else { // start searching after current column
            pos.col = V.cx + 1;
            pos.lnr = V.cy;
        }
    }
```

### Start the search

Our match is an optional slice of the `chars.items` array of the Row where the
match was found. We try to find it with the appropriate functions, which we'll
define later.

```zig
    //////////////////////////////////////////
    //          Start the search
    //////////////////////////////////////////

    var match: ?[]const u8 = null;

    if (!prev) {
        match = e.findForward(ca.input.items, &pos);
    }
    else {
        match = e.findBackward(ca.input.items, &pos);
    }

    // If wrapscan, no problems: no match is no match.
    // Otherwise it can be that we had a match, but another one isn't found in
    // the current searching direction: then we only update static.found if:
    // - either not pressing ctrl-g or ctrl-t (next or prev)
    // - or we didn't have a match to begin with
    if (opt.wrapscan or !(next or prev) or !static.found) {
        static.found = match != null;
    }
```

If a match is found, we update the cursor position and the static variables.

If `opt.wrapscan` is `false`, there's some additional considerations to make:
it's possible that we had a match, but none is found in the current searching
direction. Therefore, if searching with <kbd>Ctrl-G</kbd> or <kbd>Ctrl-T</kbd>
and a match was found before (`static.found` is `true`), we don't update the
value.

Since `match` is a slice of the original array, we can find the column with
pointer arithmetic, by subtracting the address of the first character of the
`chars.items` array from the address of the first character of our match.

```zig
    const row = e.rowAt(pos.lnr);

    if (match) |m| {
        V.cy = pos.lnr;
        V.cx = &m[0] - &row.chars.items[0];

        static.view = e.view;
        static.pos = .{ .lnr = pos.lnr, .col = V.cx };
```

<svg viewBox="0 0 500 130" xmlns="http://www.w3.org/2000/svg"><rect x="25" y="30" width="450" height="60" fill="#4ade80" stroke="#16a34a" stroke-width="2" opacity="0.7"/><rect x="175" y="30" width="120" height="60" fill="#f87171" stroke="#dc2626" stroke-width="2"/><text x="25" y="20" font-family="monospace" font-size="12" fill="#374151">&row.chars.items[0]</text><text x="175" y="120" font-family="monospace" font-size="12" fill="#374151">&m[0]</text><text x="205" y="65" font-family="Arial" font-size="14" fill="white" font-weight="bold">Match (m)</text><text x="35" y="55" font-family="Arial" font-size="14" fill="#16a34a" font-weight="bold">Row</text><text x="35" y="70" font-family="Arial" font-size="12" fill="#16a34a">(row.chars.items)</text></svg>

```admonish note
Since we pass `&pos` to the functions, we could set the column there,
but this works anyway (it's actually less trouble). Initially I wasn't using
Pos, but I'm keeping it to show an example of pointer arithmetic in Zig.
Feel free to refactor it if it suits you better.
```

Before setting the new highlight, we store a copy in `static.oldhl`. It will be
restored at the top of the callback, every time the callback is invoked.

Note that we are matching against `row.chars.items` (the real row), but the
highlight must match the characters in the rendered row, so we must convert our
match position first, with `cxToRx`.

```zig
        // first make a copy of current highlight, to be restored later
        static.oldhl = try e.alc.realloc(static.oldhl, row.render.len);
        @memcpy(static.oldhl, row.hl);

        // apply search highlight
        const start = row.cxToRx(V.cx);
        const end = row.cxToRx(V.cx + m.len);
        @memset(row.hl[start .. end], t.Highlight.incsearch);
    }
```

If a match wasn't found, we restore the initial view (before we started
searching).

We must also handle the case that `wrapscan` is disabled, a match
isn't found in the current searching direction, but there was possibly a match
before, so we just remain there, and set the highlight at current position. We
need to set it because the original has been restored at the top.

We only do this in the cases discussed above (no _wrapscan_, there was a match,
and _find next_ or _find previous_ fails).

Also here we do the same conversion, but we use the saved position.

```zig
    else if (!opt.wrapscan and static.found and (next or prev)) {
        // the next match wasn't found in the searching direction
        // we still set the highlight for the current match, since the original
        // highlight has been restored at the top of the function
        // this can definitely happen with !wrapscan
        const start = row.cxToRx(static.pos.col);
        const end = row.cxToRx(static.pos.col + ca.input.items.len);
        @memset(row.hl[start .. end], t.Highlight.incsearch);
    }
    else {
        // a match wasn't found because the input couldn't be found
        // restore the original view (from before the start of the search)
        e.view = ca.saved;
    }
```
