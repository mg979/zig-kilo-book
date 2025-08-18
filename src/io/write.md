# I/O: writing

To save files we'll use the `Io.Writer` interface. I'm not going to explain in
detail what is possible to do with it, because it has been recently introduced
into the Zig standard library, it's a vast subject and I'm not familiar with
it. So I'll stick to the minimum of informations to make our use case work.

Let's handle first the case where the filename is known, and we just want to
save the current file.

We add another _key-value pair_ to our `status_messages` string map:

<div class="code-title">message.zig: status_messages</div>

```zig
    .{ "bufwrite", "\"{s}\" {d} lines, {d} bytes written" },
```

So that we'll print a message if the save is successful.

### `ioerr()` and the error messages StringMap

Whenever a write operation fails, we'll handle the error in a helper function,
`ioerr()`:

<div class="code-title">Editor.zig</div>

```zig
/// Handle an error of type IoError by printing an error message, without
/// quitting the editor.
fn ioerr(e: *Editor, err: t.IoError) !void {
    try e.errorMessage(message.errors.get("ioerr").?, .{@errorName(err)});
    return;
}
```

As you can see, this function doesn't make the process terminate only because
we couldn't save the file for some reason. Instead, it will print an error in
the message area, with the name of the error.

### IoError

The `ioerr` function accepts an argument of type `IoError`. This is an error
union that we'll define in `types`:

<div class="code-title">types.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Error sets
//
///////////////////////////////////////////////////////////////////////////////

/// Error set for both read and write operations.
pub const IoError = std.fs.File.OpenError
                 || std.fs.File.WriteError
                 || std.Io.Reader.Error
                 || std.Io.Writer.Error;
```

It includes errors for both reading and writing, because to write a file, we
must also be able to open it, and also that can fail.

### Error messages

We keep all these error messages we'll be using in `message.zig`, in another
StringMap that we'll call `errors`:

<div class="code-title">message.zig</div>

```zig
const error_messages = .{
    .{ "ioerr", "Can't save! I/O error: {s}" },
};

pub const errors = std.StaticStringMap([]const u8).initComptime(error_messages);
```
