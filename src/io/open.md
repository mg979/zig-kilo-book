# Opening a file

In order, we're going to:

- update our buffer filename, to match the path of the file we're going to
open

- try to open the file itself and read its lines

- if that fails, we start editing an empty file with the given name


Let's update our `Editor.startUp()`:

<div class="code-title">Editor.zig: startUp()</div>

<div class="code-diff-removed">

```zig
    if (path) |name| {
        _ = name;
        // we open the file
    }
```
</div>

```zig
    if (path) |name| {
        try e.openFile(name);
    }
```

Just below `startUp()`, we inaugurate a new section for file operations, and we
add an `openFile()` function:

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              File operations
//
///////////////////////////////////////////////////////////////////////////////

/// Open a file with `path`.
fn openFile(e: *Editor, path: []const u8) !void {
    // code to come...
}
```

### Naming the buffer

We update the buffer name from the `path` argument:

<div class="code-title">Editor.zig: openFile()</div>

```zig
    var B = &e.buffer;

    // store the filename into the buffer
    B.filename = try e.updateString(B.filename, path);
```

To update the filename, we write a helper function (I put the Helpers section
at the bottom, above the Constants section):

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Helpers
//
///////////////////////////////////////////////////////////////////////////////

/// Update the string, freeing the old one and allocating from `path`.
fn updateString(e: *Editor, old: ?[]u8, path: []const u8) ![]u8 {
    t.freeOptional(e.alc, old);
    return try e.alc.dupe(u8, path);
}
```

For now we can't rename a buffer, so the old filename will always be `null`.
Which is OK _only_ because we made our `Buffer.filename` an optional type.

### Open the file

After having stored the new filename into the Buffer, we try to open the file.
`std.fs.cwd().openFile()` is how we open files, and it works on both relative
and absolute paths, so we don't have to worry about that.

<div class="code-title">Editor.zig: openFile()</div>

```zig
    // read lines if the file could be opened
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only });
    if (file) |f| {
        defer f.close();
        try e.readLines(f);
    }
```

`openFile()` expects an
[OpenMode](https://ziglang.org/documentation/0.15.1/std/#std.fs.File.OpenMode)
enum value, which is one of the following:

<div class="code-title">std.fs.File</div>

```zig
pub const OpenMode = enum {
    read_only,
    write_only,
    read_write,
};
```
We're opening to read, so our `.mode` is `.read_only`.

The function `openFile()` returns an error union, so we must do a capture on
our `if` statement, to get the value, or handle the error. If the file doesn't
exist (`error.FileNotFound`) we don't want to quit, instead we assume we're
editing a new file. If the file exists, we read its lines, without forgetting
to `close()` the file handle.

<div class="code-title">Editor.zig: openFile()</div>

```zig
    else |err| switch (err) {
        error.FileNotFound => {}, // new unsaved file
        else => return err,
    }
```
