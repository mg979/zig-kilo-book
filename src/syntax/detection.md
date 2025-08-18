# Filetype detection

We'll write a function named `selectSyntax` to detect and set the buffer
syntax. This function will be invoked in two places:

- in `openFile()`:

<div class="code-title">Editor.zig: openFile()</div>

<div class="code-diff-added">

```zig
    B.filename = try e.updateString(B.filename, path);
```
</div>

```zig
    B.syntax = try e.selectSyntax();
```

- in `saveFile()`, so that we can set a syntax for newly created files, after
we give them a name:

<div class="code-title">Editor.zig: saveFile()</div>

<div class="code-diff-added-top">

```zig
    B.syntax = try e.selectSyntax();
```
</div>

```zig
    // determine number of bytes to write, make room for \n characters
    var fsize: usize = B.rows.items.len;
```

## The `selectSyntax()` function

I put this in the "Syntax highlighting" section.

We start by freeing the old syntax, then we try to assign it again.
For now unnamed buffers can't set a syntax, but it will be selected when the
buffer is named and saved.

<div class="code-title">Editor.zig</div>

```zig
/// Return the syntax name for the current file, or null.
fn selectSyntax(e: *Editor) !?[]const u8 {
    var B = &e.buffer;

    // free the old syntax, if any
    t.freeOptional(e.alc, B.syntax);
    B.syntax = null;

    // we might allow setting a syntax even without a filename, actually...
    // but for now it's not possible
    if (B.filename == null) {
        return null;
    }

    // code to come...
}
```

We get the extension of the syntax, then we loop over all syntax definitions
and we see if any of them matches for that extension.

If none of the extension matches, we match against the tail of the filename.

<div class="code-title">Editor.zig: selectSyntax()</div>

```zig
    const fileExt = str.getExtension(B.filename.?);

    for (&syndefs.Syntaxes) |*syntax| {
        if (fileExt) |extension| {
            for (syntax.ft_ext) |ext| {
                if (str.eql(ext, extension)) {
                    B.syndef = syntax;
                    return try e.alc.dupe(u8, syntax.ft_name);
                }
            }
        }
        for (syntax.ft_fntails) |name| {
            if (str.isTail(B.filename.?, name)) {
                B.syndef = syntax;
                return try e.alc.dupe(u8, syntax.ft_name);
            }
        }
    }
    return null;
```

### Needed constants:

<div class="code-title">Editor.zig</div>

```zig
const syndefs = @import("syndefs.zig");
```
