# Saving a file

<div class="code-title">Editor.zig</div>

```zig
/// Try to save the current file, prompt for a file name if currently not set.
/// Currently saving the file fails if directory doesn't exist, and there is no
/// tilde expansion.
fn saveFile(e: *Editor) !void {
    var B = &e.buffer;

    if (B.filename == null) {
        // will prompt for a filename
        return;
    }

    // code to come...
}
```

Before saving, we want to determine in advance how many bytes we'll write to
disk, so that we can print it in a message.

Since `e.buffer.filename` is optional, once we are certain that it can't be
`null`, we can access safely its non-null value with the `.?` notation.

<div class="code-title">Editor.zig: saveFile()</div>

```zig
    // determine number of bytes to write, make room for \n characters
    var fsize: usize = B.rows.items.len;
    for (B.rows.items) |row| {
        fsize += row.chars.items.len;
    }

    const file = std.fs.cwd().createFile(B.filename.?, .{ .truncate = true });
    if (file) |f| {
        // write lines to file
    }
    else |err|{
        e.alc.free(B.filename.?);
        B.filename = null;
        return e.ioerr(err);
    }
```

We will try to open the file in writing mode, truncating it and replacing all
bytes. Here the key _std_ function is `std.fs.cwd().createFile()`.

In this block we write the lines:

<div class="code-title">Editor.zig: saveFile()</div>

```zig
    if (file) |f| {
```
<div class="code-diff-removed">

```zig
        // write lines to file
```
</div>

```zig
        var buf: [1024]u8 = undefined;
        var writer = f.writer(&buf);
        defer f.close();
        // for each line, write the bytes, then the \n character
        for (B.rows.items) |row| {
            writer.interface.writeAll(row.chars.items) catch |err| return e.ioerr(err);
            writer.interface.writeByte('\n') catch |err| return e.ioerr(err);
        }
        // write what's left in the buffer
        try writer.interface.flush();
        try e.statusMessage(message.status.get("bufwrite").?, .{
            B.filename.?, B.rows.items.len, fsize
        });
        B.dirty = false;
        return;
```

Before writing, we need a buffered writer. The size doesn't matter too much
I think, but too small would be close to unbuffered.

To actually write the file, we use the `Io.Writer` interface, which is accessed
at `writer.interface`.

After we wrote all bytes, we have to _flush_ the writer. This is what happens:

<div class="numbered-table">

| | |
|-|-|
|1. | we provide a small buffer, that lives on the stack |
|2. | this buffer is filled by the _writer_ with characters that have to be written |
|3. | when the buffer is full, the _writer_ actually writes the data, then empties the buffer and repeats |
|4. | when there's nothing more to write, there can be something left in the buffer, because the _writer_ only writes the buffer when it's full |
|5. | so we _flush_ the buffer: the _writer_ empties it and writes what's left |

</div>

When we're done we print a message that says the name of the written file, how
many lines and bytes have been written to disk.

If for some reason the write fails, the buffer filename is freed and made null.

```admonish important
The same remarks that have been made for the `Io.Reader` interface are valid
here: you **can't** make a copy of the interface, by assigning it directly:

<pre class="code-block-small"><code class="language-zig">const interface = f.writer(&buf).interface; // WRONG
</code></pre>
```
