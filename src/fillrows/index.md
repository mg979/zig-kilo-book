# Filling rows

Now that we can read a file line by line, we must store these lines in our
Buffer rows.

We'll modify `readLines()` so that it will insert the row.

<div class="code-title">Editor.zig: readLines()</div>

<div class="code-diff-removed">

```zig
    _ = e;
```
</div>

```zig
    var buf: [1024]u8 = undefined;
    var reader = file.reader(&buf);
```

<div class="code-diff-removed">

```zig
    while (reader.interface.takeDelimiterExclusive('\n')) |line| {
        // we print the line to stderr, to see if it works
        std.debug.print("{s}\n", .{line});
```
</div>

```zig
    while (reader.interface.takeDelimiterExclusive('\n')) |line| {
        try e.insertRow(e.buffer.rows.items.len, line);
```

which means that we'll insert a row at the last index of `Buffer.rows`.

### Watch out the reading buffer

We'll also fix one problem of the current way we're reading the file. We're
using a fixed buffer which is placed on the stack, and that's ok, because our
`file.reader` needs a buffer. But the way this reader works, is that this
buffer is filled with the line that is being read, then a row is inserted with
the content of this buffer.

If the line is longer than the buffer, the program will quit with an error:

    error: StreamTooLong

I don't know if there's a way to salvage the line that has just been read and
be able to handle the error in the `else` branch. My first guess is _no_.

We could allocate a very large buffer and use that:

```zig
    const buf = try e.alc.alloc(u8, 60 * 1024 * 1024);
    defer e.alc.free(buf);
    var reader = file.reader(buf);
```

But this approach has multiple problems:

- it's very slow, because allocating such a large buffer is expensive
- we could get a `OutOfMemory` error
- it doesn't solve the problem that you might still have files with lines
longer than that

### Using an allocating Reader

So we use another solution (suggested on [Ziggit
forum](https://ziggit.dev/t/0-15-1-reader-writer/11614/9)):

<div class="code-title">Editor.zig: readLines()</div>

<div class="code-diff-removed">

```zig
    while (reader.interface.takeDelimiterExclusive('\n')) |line| {
        try e.insertRow(e.buffer.rows.items.len, line);
    }
    else |err| if (err != error.EndOfStream) return err;
```
</div>

```zig
    var line_writer = std.Io.Writer.Allocating.init(e.alc);
    defer line_writer.deinit();

    while (reader.interface.streamDelimiter(&line_writer.writer, '\n')) |_| {
        try e.insertRow(e.buffer.rows.items.len, line_writer.written());
        line_writer.clearRetainingCapacity();
        reader.interface.toss(1); // skip the newline
    }
    else |err| if (err != error.EndOfStream) return err;
```

This approach makes the reader not store the line it is reading in a `line`
slice, but it will feeding it to an allocating `Writer`, that stores the line
in itself, allocating as much as it is needed.

It uses another method of the `Reader` interface:

- instead of `takeDelimiterExclusive`, which doesn't take a `Writer` as
argument, it will use `streamDelimiter`, which does

- it must toss the last character, because `streamDelimiter` doesn't skip it,
like `takeDelimiterExclusive` would do

### Way too complex?

You can see that this is quite complex. I needed the help of experienced Zig
users just to read the lines of the file. But this is a temporary problem,
because the `Reader` and `Writer` interfaces are very new, and they still lack
convenience, which has been already been promised and will come soon in the
next Zig versions.
