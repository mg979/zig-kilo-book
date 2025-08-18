# Highlight for non-printable characters

As a first proof-of-concept for our highlight, we want non-printable characters
to be printed with a reversed highlight (black on white), for example we'll
turn <kbd>Ctrl-A</kbd> into `A` with reversed colors. If the character is not
a Ctrl character, it will be printed as `?` with reversed colors.

It won't work for some charcters like <kbd>Tab</kbd> or <kbd>Backspace</kbd>,
though, but for now it will do.

This kind of highlight will work with all filetypes, so we aren't talking about
_syntax_ highlighting yet.

We'll need a way to insert non-printable characters, so we define a key
(<kbd>Ctrk-K</kbd>) which will let us insert characters _verbatim_, even those
that we couldn't type anyway. For example <kbd>Ctrl-Q</kbd> would quit, it
would not insert it. But while inserting characters _verbatim_ we'll be able to
type it.

### Process _verbatim_ keypresses

In `processKeypress()`, we add a variable `verbatim` in the `static` struct:

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
    const static = struct {
        var q: u8 = opt.quit_times;
```

<div class="code-diff-added-top">

```zig
        var verbatim: bool = false;
```
</div>

Just below the `static` struct definition, before processing keypresses, we
check if the variable was set, in this case we reset the variable, insert the
character and return. There is a set of characters that we don't insert,
because we cannot handle them at this point, they would just break our text.

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
    if (static.verbatim) {
        static.verbatim = false;
        switch (k) {
            // these cause trouble, don't insert them
            .enter,
            .ctrl_h,
            .backspace,
            .ctrl_j,
            .ctrl_k,
            .ctrl_l,
            .ctrl_u,
            .ctrl_z,
            => {
                try e.errorMessage(message.errors.get("nonprint").?, .{ k });
                return;
            },
            else => try e.insertChar(@intFromEnum(k)),
        }
        return;
    }
```

We'll make <kbd>Ctrl-K</kbd> set this variable to `true`:

<div class="code-title">Editor.zig: processKeypress() switch</div>

```zig
        .ctrl_k => static.verbatim = true,
```

For the error, we need the `nonprint` error message:

<div class="code-title">message.zig: error_messages</div>

```zig
    .{ "nonprint", "Can't insert character: {any}" },
```

### Highlight the _verbatim_ characters

This highlight group is filetype-independent, so we just handle it in the
`drawRows()` inner loop:

<div class="code-title">Editor.zig: drawRows() inner loop</div>

<div class="code-diff-removed">

```zig
                if (hl[i] != current_color) {
```
</div>

```zig
                if (c != '\t' and !asc.isPrint(c)) {
                    // for example, turn Ctrl-A into 'A' with reversed colors
                    current_color = t.Highlight.nonprint;
                    try e.toSurface(t.HlGroup.attr(.nonprint));
                    try e.toSurface(switch (c) {
                        0...26 => '@' + c,
                        else => '?',
                    });
                }
                else if (hl[i] != current_color) {
```

We also need to add `nonprint` to the `Highlight` enum:

<div class="code-title">types.zig: Highlight enum</div>

```zig
    /// Highlight for non-printable characters
    nonprint,
```

### Define the highlight group

Now, if you try to compile, the compiler will say something like:

    src/types.zig|162 col 20| error: use of undefined value here causes illegal behavior
    ||             if (hlg.bold) "1;" else "22;",

That's because we didn't define the highlight group in `hlGroups`, but the
`hlAttrs` initializer tries to access it. This means that our system is really
ok! We can't forget to define groups without the compiler telling us.

So we add the highlight group in the `hlGroups` labeled block:

<div class="code-title">types.zig</div>

```zig
    hlg[int(.nonprint)] = .{
        .fg = FgColor.white,
        .bg = BgColor.default,
        .reverse = true,
        .bold = false,
        .italic = false,
        .underline = false,
    };
```

Now it should compile and the following should work:

- try inserting a non-printable character with <kbd>Ctrl-K</kbd> followed by
<kbd>Ctrl-A</kbd>

- now try pressing two times <kbd>Ctrl-K</kbd>: we decided not insert certain
characters and print an error message instead, this should have the `.err`
highlight.
