# Reading keys

The `ansi` module needs a new constant, from the Zig standard library:

<div class="code-title">ansi.zig</div>

```zig
const asc = std.ascii;
```

Let's write `ansi.readKey()`.

<div class="code-title">ansi.zig</div>

```zig
/// Read a character from stdin. Wait until at least one character is
/// available.
pub fn readKey() !t.Key {
    // code to come...
}
```

We'll use a `[4]u8` buffer to store the keys that will be read. We'll feed this
to the same `readChars()` that we've used before.

<div class="code-title">ansi.zig: readKey()</div>

```zig
    // we read a sequence of characters in a buffer
    var seq: [4]u8 = undefined;
    const nread = try linux.readChars(&seq);

    // if the first character is ESC, it could be part of an escape sequence
    // in this case, nread will be > 2, that means that more than two
    // characters have been read into the buffer, and it's an escape sequence
    // for sure, if we can't recognize this sequence we return ESC anyway
```

If you remember, that function has a loop that ignores `.WouldBlock` errors,
and it's guaranteed to read at least one byte from `stdin` before returning. If
the keypress is a special key which uses CSI escape sequences, there will be
more characters. We read up to 4 characters, then we decide what to do with
them.

You can verify that the sequences are correct by opening a terminal, pressing
<kbd>Ctrl-V</kbd> and then the key. For example:

| keys | sequence | character-by-character |
|----------|----------|----------|
| <kbd>Ctrl-V</kbd><kbd>Left</kbd>          | `^[[D`         | `ESC [ D`         |
| <kbd>Ctrl-V</kbd><kbd>Del</kbd>          | `^[[~3`         | `ESC [ ~ 3`         |

We use `@enumFromInt` to cast a character in the sequence to a `Key` enum
member, which might not be defined, but it won't be a problem since our enum is
non-exhaustive.

<div class="code-title">ansi.zig: readKey()</div>

```zig
    const k: t.Key = @enumFromInt(seq[0]);
```

Note that this function doesn't guarantee that we interpret all possible escape
sequences: if a sequence isn't recognized, ESC is returned.

We also handle the case that more than one character has been read, but it's
not an escape sequence (`nread > 1`). It's possibly a multi-byte character and
we don't handle those, so we return ESC.

If instead it's a single character, it is returned as-is.

<div class="code-title">ansi.zig: readKey()</div>

```zig
    if (k == .esc and nread > 2) {
        if (seq[1] == '[') {
            if (nread > 3 and asc.isDigit(seq[2])) {
                if (seq[3] == '~') {
                    switch (seq[2]) {
                        '1' => return .home,
                        '3' => return .del,
                        '4' => return .end,
                        '5' => return .page_up,
                        '6' => return .page_down,
                        '7' => return .home,
                        '8' => return .end,
                        else => {},
                    }
                }
            }
            switch (seq[2]) {
                'A' => return .up,
                'B' => return .down,
                'C' => return .right,
                'D' => return .left,
                'H' => return .home,
                'F' => return .end,
                else => {},
            }
        }
        else if (seq[1] == 'O') {
            switch (seq[2]) {
                'H' => return .home,
                'F' => return .end,
                else => {},
            }
        }
        return .esc;
    }
    else if (nread > 1) {
        return .esc;
    }
    return k;
```

### `clearScreen()`

We also add a `clearScreen()` function:

<div class="code-title">ansi.zig</div>

```zig
/// Clear the screen.
pub fn clearScreen() !void {
    try linux.write(ClearScreen);
}
```

At this point, if we compile and run we should get an empty prompt, if we then
press <kbd>Ctrl-Q</kbd> three times in a row the program should clear the
screen and quit.
