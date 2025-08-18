# The cursor position method

In case of failure, we'll have to resort to a second method.

We replace the commented line in `getWindowSize()` with:

<div class="code-diff-removed">

```zig
    if (linux.winsize(&wsz) == -1 or wsz.col == 0) {
        // fallback method will be here
```
</div>

```zig
    if (linux.winsize(&wsz) == -1 or wsz.col == 0) {
        screen = try getCursorPosition();
```

Our `getCursorPosition()` function also goes just below `getWindowSize()`:

<div class="code-title">ansi.zig</div>

```zig
/// Get the cursor position, to determine the window size.
pub fn getCursorPosition() !t.Screen {
    // code to come...
}
```

What should we do in there? The idea is to maximize the terminal screen, so
that the cursor is positioned to the bottom-right corner, and read the current
row and column from there.

For both things, we need issue escape sequences to the terminal.

- to maximize the screen, we'll issue two sequences in a row, one to set the
columns and one to set the rows.

- to read the cursor position, we'll issue a sequence, and read the response of
  the terminal in a `[]u8` buffer

### ANSI escape sequences

We'll define the following constants in `ansi.zig`:

<div class="code-title">ansi.zig</div>

```zig
/// Control Sequence Introducer: ESC key, followed by '[' character
pub const CSI = "\x1b[";

/// The ESC character
pub const ESC = '\x1b';

// Sets the number of column and rows to very high numbers, trying to maximize
// the window.
pub const WinMaximize = CSI ++ "999C" ++ CSI ++ "999B";

// Reports the cursor position (CPR) by transmitting ESC[n;mR, where n is the
// row and m is the column
pub const ReadCursorPos = CSI ++ "6n";
```

### `linux.write()`

How exactly do we send these sequences? We're back into `linux.zig`.

<div class="code-title">linux.zig</div>

```zig
// Write bytes to stdout, return error if the requested amount of bytes
// couldn't be written.
pub fn write(buf: []const u8) !void {
    if (try posix.write(STDOUT_FILENO, buf) != buf.len) {
        return error.WriteIncomplete;
    }
}
```

`WriteIncomplete` in this case is an error I just made up, probably it's not
a very good way to handle incomplete writes, in the sense that we should
probaby retry. In my defense, I can say that the original C editor did this:

<div class="code-title">C</div>

```c
  if (write(STDOUT_FILENO, "\x1b[6n", 4) != 4) return -1;
```

which means that it gave up all the same. Hey... I think we're trying hard
enough already. At least for our humble editor, that is.

### Back to `getCursorPosition()`

Now it's hopefully clear what we'll do:

1. issue sequences to maximize screen and to report cursor position
2. read the response in a `[]u8` buffer
3. parse the result, to extract the screen size

<div class="code-title">ansi.zig: getCursorPosition()</div>

```zig
    var buf: [32]u8 = undefined;

    try linux.write(WinMaximize ++ ReadCursorPos);

    var nread = try linux.readChars(&buf);
```

What's that `readChars()` over there?

This is actually the function that we'll use to read all input from `stdin`, so
it's worth taking care of it right now. It's not too different from the
`readChar()` function we wrote in `main.zig` and that we carelessly deleted
when we didn't need it anymore.

### `linux.readChars()`

<div class="code-title">linux.zig</div>

```zig
/// Keep reading from stdin until we get a valid character, ignoring
/// .WouldBlock errors.
pub fn readChars(buf: []u8) !usize {
    while (true) {
        const n = posix.read(STDIN_FILENO, buf) catch |err| switch (err) {
            error.WouldBlock => continue,
            else => return err,
        };
        if (n >= 1) return n;
    }
}
```

Let's compare it with the previous `readChar()` function which was:

```zig
// Read from stdin into `buf`, return the number of read characters.
fn readChar(buf: []u8) !usize {
    return try posix.read(STDIN_FILENO, buf);
}
```

The main difference is that now we are in raw mode, and there is a `read()`
timeout in place, so we must handle the error which happens when the timeout
kicks in. This error is `.WouldBlock`, and we must ignore it, that is, we must
keep reading until we read something, or a different error is returned by
`posix.read()`.

If `posix.read()` finally returns a positive number because it read something,
we return it. If it didn't read anything, it's probably because we didn't type
anything, and the loop continues.

### Back to `getCursorPosition()`

So now we got the response from the terminal, and we read it inside our `[]u8`
buffer.

<div class="code-title">ansi.zig: getCursorPosition()</div>

<div class="code-diff-added">

```zig
    var nread = try linux.readChars(&buf);
```
</div>

```zig
    if (nread < 5) return error.CursorError;
```

For a response to be valid, it should follow this format:

    ESC ] rows ; cols R

for example, `0x1b]50;120R`. This sequence has a minimum of 5 characters, plus
the final `R`. I think in some occasions I couldn't read the `R` character
immediately, but maybe I've been doing something wrong? Anyway this is what we
do:

<div class="code-title">ansi.zig: getCursorPosition()</div>

```zig
    // we should ignore the final R character
    if (buf[nread - 1] == 'R') {
        nread -= 1;
    }
    // not there yet? we will ignore it, but it should be there
    else if (try linux.readChars(buf[nread..]) != 1 or buf[nread] != 'R') {
        return error.CursorError;
    }
```
That is, we keep reading until we get this `R` character, if it's not yet in
our buffer. Since we don't want to overwrite our previous response, we pass
a slice that starts at `nread`, which is the number of characters that have
been read until now. When `R` is finally read, `buf[nread]` should hold it.

If the first two characters aren't `ESC ]`, we error out:

<div class="code-title">ansi.zig: getCursorPosition()</div>

```zig
    if (buf[0] != ESC or buf[1] != '[') return error.CursorError;
```

Finally we must parse the number of rows and columns. The original C code used
`sscanf()` for this purpose, but we won't use `libc` in this project. We parse
it by hand.

<div class="code-title">ansi.zig: getCursorPosition()</div>

```zig
    var screen = t.Screen{};
    var semicolon: bool = false;
    var digits: u8 = 0;

    // no sscanf, format to read is "row;col"
    // read it right to left, so we can read number of digits
    // stop before the CSI, so at index 2
    var i = nread;
    while (i > 2) {
        i -= 1;
        if (buf[i] == ';') {
            semicolon = true;
            digits = 0;
        }
        else if (semicolon) {
            screen.rows += (buf[i] - '0') * try std.math.powi(usize, 10, digits);
            digits += 1;
        } else {
            screen.cols += (buf[i] - '0') * try std.math.powi(usize, 10, digits);
            digits += 1;
        }
    }
    if (screen.cols == 0 or screen.rows == 0) {
        return error.CursorError;
    }
    return screen;
```

If you did programming exercises before, this method of parsing integers should
be familiar. The Zig standard library has a function for this purpose
(`std.fmt.parseInt`), but in this case it wouldn't have spared us much trouble.
There's a semicolon between the numbers, and we would have needed to track the
start and end position of both numbers.
