# Interacting with the user

At various points of our program, we'll want to interact with the users, either
by notifying them of something, or by requesting something.

For example, we want to print a "help" sort of message when the editor starts,
we must prompt for a filename when trying to save an unnamed buffer, or for
a word when using the searching functionality.

We have already added the `status_msg` field in Editor, so we must add
a function that prints it.

We'll have two ways to print, either normal messages (or prompts) using regular
highlight, or _error_ messages, which we'll print in a bright red color.

### `statusMessage()`

What this function does, is clearing the previous content, and replace it with
a new one, which we'll format on the fly by using the `ArrayList(u8)` method
`print()`. Note that this method only works if the base type of the array is
`u8`.

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Message area
//
///////////////////////////////////////////////////////////////////////////////

/// Set a status message, using regular highlight.
pub fn statusMessage(e: *Editor, comptime format: []const u8, args: anytype) !void {
    assert(format.len > 0);
    e.status_msg.clearRetainingCapacity();
    try e.status_msg.print(e.alc, format, args);
    e.status_msg_time = time();
}
```

`print()` uses `std.Io.Writer`, we'll see this interface again when we'll want
to save a file.

We never pass an empty format, so we `assert()` that the format is not empty.
You have to define a `assert` constant (do it yourself).

Finally we update `status_msg_time`, so that the message will be actually
printed, then cleared after a while.

```admonish note
This function doesn't really _print_ anything on screen: the actual printing
will be done in `drawMessageBar()`, which we already wrote.
```

Compile and run to see your "help" message printed in the message area when you
start up the editor.

### `errorMessage()`

This function is similar, but it will color the message in bright red, since
it's supposed to be an error. Note that we can use the `++` string
concatenation operator, since all values are comptime-known.

<div class="code-title">Editor.zig</div>

```zig
/// Print an error message, using error highlight.
pub fn errorMessage(e: *Editor, comptime format: []const u8, args: anytype) !void {
    assert(format.len > 0);
    e.status_msg.clearRetainingCapacity();
    const fmt = ansi.ErrorColor ++ format ++ ansi.ResetColors;
    try e.status_msg.print(e.alc, fmt, args);
    e.status_msg_time = time();
}
```
### The 'help' message

Let's take care of the "help" message.

<div class="code-title">Editor.zig: startUp()</div>

```zig
pub fn startUp(e: *Editor, path: ?[]const u8) !void {
```

<div class="code-diff-added-top">

```zig
    try e.statusMessage(message.status.get("help").?, .{});
```
</div>

`help` should be a _key_ in our message string map, but we don't have it yet,
so add it to `status_messages`:

<div class="code-title">message.zig: status_messages</div>

```zig
    .{ "help", "HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find" },
```

### The 'unsaved' message

Let's add a message that warns us when we press <kbd>Ctrl-Q</kbd> and there are
unsaved changes:

<div class="code-title">message.zig: status_messages</div>

```zig
    .{ "unsaved", "WARNING!!! File has unsaved changes. Press Ctrl-Q {d} more times to quit." },
```

We print this message in `processKeypress`:

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
        .ctrl_q => {
            if (B.dirty and static.q > 0) {
```

<div class="code-diff-added-top">

```zig
                try e.statusMessage(message.status.get("unsaved").?, .{static.q});
```
</div>

Now, if we have unsaved changes, we'll get this warning, telling us how many
times we must press <kbd>Ctrl-Q</kbd> to quit.

### Needed constants:

<div class="code-title">Editor.zig</div>

```zig
const assert = std.debug.assert;
```
