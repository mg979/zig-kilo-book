# The welcome message

The original `kilo` editor would print a welcome message when the program is
started without arguments, which results in a new empty, unnamed buffer to be
created.

We also want it because it's cool and reminds us (or at least me) of vim.

New fields in `Editor`:

<div class="code-title">Editor.zig</div>

```zig
/// String to be displayed when the editor is started without loading a file
welcome_msg: t.Chars,

/// Becomes false after the first screen redraw
just_started: bool,
```

Initialize in `init()`.

<div class="code-title">Editor.zig: init()</div>

```zig
        .welcome_msg = try t.Chars.initCapacity(allocator, 0),
        .just_started = true,
```

Deinitialize in `deinit()`:

<div class="code-title">Editor.zig: deinit()</div>

```zig
    e.welcome_msg.deinit(e.alc);
```

When, how, and where do we want the welcome message to appear?

- we generate it when the argument for `startUp()` is `null`, which means
there's no file to open

- we want to generate it dynamically because the message should be centered on
screen, and we can assess that only at runtime

- we render the message in `drawRows()`

### A module for messages

When generating the message, we must fetch the base string from somewhere.
It will be the same for other text constants and messages that we'll use in the
editor in the future. So we create a `message` module and we import it in
Editor:

```zig
const message = @import("message.zig");
```

This module for now will look like this:

<div class="code-title">message.zig</div>

```zig
//! Module that holds various strings for the message area, either status or
//! error messages, or prompts.

const std = @import("std");
const opt = @import("option.zig");

const status_messages = .{
    .{ "welcome", "Kilo editor -- version " ++ opt.version_str },
};

pub const status = std.StaticStringMap([]const u8).initComptime(status_messages);
```

We also create a `version_str` in our `option` module, so that it contains the
current version number, as a string:

<div class="code-title">option.zig</div>

```zig
pub const version_str = "0.1";
```

The `StaticStringMap` is created at compile time (see how it's initialized),
and will be accessed in Editor with `message.status.get()`, that returns an
_optional value_ which is `null` if the _key_ couldn't be found.

_Keys_ of `StaticStringMap` will always be strings, but _values_ can be of any
type. In our case they are also strings (`[]const u8`).

### Generate the message

We had a commented placeholder in `startUp()`, so we must replace it with the
actual function call.

<div class="code-title">Editor.zig: startUp()</div>

<div class="code-diff-removed">

```zig
    else {
        // we generate the welcome message
    }
```
</div>

```zig
    else {
        try e.generateWelcome();
    }
```

The function to generate the message is:

<div class="code-title">Editor.zig</div>

```zig
/// Generate the welcome message.
fn generateWelcome(e: *Editor) !void {
    // code to come...
}
```

The line with the welcome message starts with a `~`, because we're in an empty
buffer.

The length of the message must be limited to the screen columns - 1, because of
the `~` which we just appended.

<div class="code-title">Editor.zig: generateWelcome()</div>

```zig
    try e.welcome_msg.append(e.alc, '~');

    var msg = message.status.get("welcome").?;
    if (msg.len >= e.screen.cols) {
        msg = msg[0 .. e.screen.cols - 1];
    }
```

The padding will be inserted before the message.

<div class="code-title">Editor.zig: generateWelcome()</div>

```zig
    const padding: usize = (e.screen.cols - msg.len) / 2;

    try e.welcome_msg.appendNTimes(e.alc, ' ', padding);
    try e.welcome_msg.appendSlice(e.alc, msg);
```

### Render the message

In `drawRows()`, all we have to do is replace the `if` branch for when the row
is past the end of the buffer, with this:

<div class="code-title">Editor.zig: drawRows()</div>

<div class="code-diff-removed">

```zig
        // past buffer content
        if (ix >= rows.len) {
            try e.toSurface('~');
```
</div>

```zig
        // past buffer content
        if (ix >= rows.len) {
            if (e.just_started
                and e.buffer.filename == null
                and e.buffer.rows.items.len == 0
                and y == e.screen.rows / 3) {
                try e.toSurface(e.welcome_msg.items);
            }
            else {
                try e.toSurface('~');
            }
```

We append it to the surface if the buffer is empty, doesn't even have a name,
and current row is at about 1/3 of the height of the screen.

Remember to set `just_started` to `false` at the bottom of `refreshScreen()`,
if you didn't already.

<div class="code-title">Editor.zig: refreshScreen()</div>

<div class="code-diff-added-top">

```zig
    e.just_started = false;
```
</div>

```zig
    try linux.write(e.surface.items);
```

We also set `just_started` to `false` so that our welcome message won't be
printed again.

Compile and run with

    ./kilo

to see an empty buffer and the welcome message. You can try to run again with
a narrower terminal window, to verify that the message and the statusline are
displayed correctly.
