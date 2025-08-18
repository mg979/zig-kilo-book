# Enabling raw mode

```admonish note
The original booklet I mentioned in the introduction goes into [great
detail](https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html) in
explaining what all the flags mean. I have no intention to do that, if you are
curious about them you can consult the original.
```

First we make a copy of the original configuration, so that we can modify it.

<div class="code-diff-removed">

```zig
    // stuff here
```
</div>

```zig
    // make a copy
    var termios = orig_termios;
```

We then set a number of flags in this copy. We disable echoing of the
characters we type:

```zig
    termios.lflag.ECHO = false; // don't echo input characters
```
We disable canonical mode, so that the terminal doesn't wait for
<kbd>Enter</kbd> to be pressed when reading characters:

```zig
    termios.lflag.ICANON = false; // read input byte-by-byte instead of line-by-line
```

We disable some key combinations that usually have a special behavior in
terminals, so that are available for us to use them in our program:
```zig
    termios.lflag.ISIG = false; // disable Ctrl-C and Ctrl-Z signals
    termios.iflag.IXON = false; // disable Ctrl-S and Ctrl-Q signals
    termios.lflag.IEXTEN = false; // disable Ctrl-V
    termios.iflag.ICRNL = false; // CTRL-M being read as CTRL-J
```
For reference:

| key | default behavior |
|----------|----------|
| <kbd>Ctrl-C</kbd> | sends a `SIGINT` signal that causes the program to terminate         |
| <kbd>Ctrl-Z</kbd> | sends a `SIGSTOP` signal which causes the suspension of the program (which you can then resume with `fg` in the terminal command line)|
| <kbd>Ctrl-S</kbd> | produces `XOFF` control character, halts data transmission |
| <kbd>Ctrl-Q</kbd> | produces `XON` control character, resumes data transmission |
| <kbd>Ctrl-V</kbd> | next character will be inserted literally |
| <kbd>Ctrl-M</kbd> | read as ASCII `10` <kbd>Ctrl-J</kbd> instead of `13` <kbd>Enter</kbd> |

Let's disable output processing, to prevent the terminal to issue a carriage
return (`\r`) in addition to each new line (`\n`) when <kbd>Enter</kbd> is
pressed:
```zig
    termios.oflag.OPOST = false; // disable output processing
```

You can see that the termios flags are placed into structs that start either
with `i` (input, as in `iflags`) or `o` (output, as in `oflags`).

Let's disable more flags, which are even more obscure than the previous ones
and that I won't even try to explain (sorry):

```zig
    termios.iflag.BRKINT = false; // break conditions cause SIGINT signal
    termios.iflag.INPCK = false; // disable parity checking (obsolete?)
    termios.iflag.ISTRIP = false; // disable stripping of 8th bit
    termios.cflag.CSIZE = .CS8; // set character size to 8 bits
```

```admonish quote collapsible=true title="From the original booklet"
This step probably won’t have any observable effect for you, because these
flags are either already turned off, or they don’t really apply to modern
terminal emulators. But at one time or another, switching them off was
considered (by someone) to be part of enabling “raw mode”, so we carry on the
tradition (of whoever that someone was) in our program.

As far as I can tell:

- When BRKINT is turned on, a break condition will cause a SIGINT signal to
  be sent to the program, like pressing Ctrl-C.
- INPCK enables parity checking, which doesn’t seem to apply to modern
  terminal emulators.
- ISTRIP causes the 8th bit of each input byte to be stripped, meaning it
  will set it to 0. This is probably already turned off.
- CS8 is not a flag, it is a bit mask with multiple bits, which we set
  using the bitwise-OR (|) operator unlike all the flags we are turning
  off. It sets the character size (CS) to 8 bits per byte. On my system,
  it’s already set that way.
```

## A timeout for `read()`

Finally, we want to set a timeout for `read()`, so that our editor will be able
to discern an <kbd>Esc</kbd> from an escape sequence. In fact, all terminal
escape sequences that codify for many keys begin with an <kbd>Esc</kbd> (that's
why they are called *escape sequences*), and we want to be able to handle them
accordingly.

Here we use some constants that are defined in `std.os.linux`. Since they are
in an `enum`, we'll have to use the builtin function `@intFromEnum()` so that
we can use them for array indexing (which expects an `usize` type).

```zig
    // Set read timeouts
    termios.cc[@intFromEnum(linux.V.MIN)] = 0; // Return immediately when any bytes are available
    termios.cc[@intFromEnum(linux.V.TIME)] = 1; // Wait up to 0.1 seconds for input
```
```admonish important
This took me hours to figure out. The original kilo editor uses constants that
come from the _libc_ `termios.h` header, but initially I simply used the values
from the C version, thinking they would apply also for the Zig version. They
didn't work, that is, there was no read timeout. I initially asked the AI, and
it didn't help. I then looked for other Zig implementations of this same editor
on the internet, but all of them repeated this mistake, until I found one
implementation that did the right thing, that is, to use the constants that are
provided by the Zig standard library (what is being done in the snippet of code
above).

The lesson was: don't try to reinvent a system-defined constant, use the
system-defined constant, even if it means that you must look for it in the
standard library.
```

We're done, we can apply the new terminal configuration and return the original
one:

<div class="code-diff-added-top">

```zig
    // update config
    try posix.tcsetattr(STDIN_FILENO, .FLUSH, termios);
```
</div>

```zig
    return orig_termios;
```
