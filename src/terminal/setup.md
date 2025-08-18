# Terminal configuration

When we write text in an editor, the character is immediately read and handled
by the program. This is not what happens normally in a terminal, because the
default way a terminal handles keypresses is the so-called **canonical
mode**: in this mode, keys are sent to the program only after the user presses
the <kbd>Enter</kbd> key.

Let's write first a function that can read bytes from the user keypresses:

<div class="code-title">main.zig</div>

```zig
// Read from stdin into `buf`, return the number of read characters
fn readChar(buf: []u8) !usize {
    const stdin = std.posix.STDIN_FILENO;
    return try std.posix.read(stdin, buf);
}
```

This will read from `stdin` one character at a time, store the read character
in `buf` and return the number of characters that have been read.
`buf` should be a slice, because `std.posix.read` accepts a slice as parameter.

In general, you'll find out that working with slices will prevent a lot of
headaches, because the Zig type system is very strict, but most functions of
the standard libraries that work with arrays are designed to take a slice as
parameter. You still keep the ownership of the underlying array, of course.

Remeber that to pass a slice of an array to a function we use one of the
following notations:

```zig
    &array      // create the slice by taking the address of an array
    array[0..]  // a slice with all elements of an array
```

Let's call it from `main()` by adding these lines:

<div class="code-diff-added">

```zig
    };
    _ = allocator;
```
</div>

```zig
    var buf: [1]u8 = undefined;
    while (try readChar(&buf) == 1 and buf[0] != 'q') {}
```

If you build and run the program in a terminal, you'll see that even if you
press <kbd>q</kbd> the loop doesn't stop, you need to press <kbd>Enter</kbd>,
and if you press any key after <kbd>q</kbd>, you'll find those characters in
your command line prompt.

So you'll understand the need to change how the terminal sends what it reads to
our program, and this is what **raw mode** is for.

For this purpose, we'll create a new module for our program, we'll call it
`linux`, and it will handle all interactions with the operating system, such as
reading characters.
