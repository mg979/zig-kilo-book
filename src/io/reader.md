# Io.Reader

`std.fs.File` implements the `Io.Reader` interface, so we'll use that to read
its lines. A simple pattern would be like the following:

<div class="code-title">Editor.zig</div>

```zig
/// Read all lines from file.
fn readLines(e: *Editor, file: std.fs.File) !void {
    _ = e;
    var buf: [1024]u8 = undefined;
    var reader = file.reader(&buf);

    while (reader.interface.takeDelimiterExclusive('\n')) |line| {
        // we print the line to stderr, to see if it works
        std.debug.print("{s}\n", .{line});
    }
    else |err| if (err != error.EndOfStream) return err;
}
```

`file` is the file that has already been opened and is ready to be read.
We create a buffer on the stack, then we initialize its reader. `Io.Reader`
actually lives in `reader.interface`, so `Io.Reader` methods will be called on
the interface.

We stop at error `.EndOfStream`, which means our file has been fully read.
Other errors instead should be handled.

Now, this implementation is simple, but it has a problem: the buffer is on the
stack, and has fixed size. Which means that we can't read lines longer than its
size. If a file has lines that are longer than that, it will error out. We'll
fix this later.

Anyway, let's test this. Create a file named `kilo` at the root of the project:

<div class="code-title">~/kilo-zig/kilo</div>

```sh
#!/bin/sh

~/kilo-zig/zig-out/bin/kilo "$@" 2>err.txt
```

Then

    chmod u+x kilo

It will run the program and write `stderr` output to `err.txt`. Compile and run
with an argument, the lines of the file should be written into `err.txt`:

    ./kilo src/main.zig

Remember that we still have to press 3 times <kbd>Ctrl-Q</kbd> to quit.

