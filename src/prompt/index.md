# Prompts

We're back to the point where we need to interact with the user, in this case
to obtain a filename for a buffer that doesn't have one, so that we can save
it.


### The prompt function

We'll put this function in the Message Area section, right above the
`statusMessage` and `errorMessage` functions.

For now this is a simplified version, we'll have to expand it later, when we'll
want this prompt to accept a callback as argument, so that this callback can be
invoked at each user input. But right now we don't need it, so we keep it at
its simplest.

<div class="code-title">Editor.zig</div>

```zig
/// Start a prompt in the message area, return the user input.
/// Prompt is terminated with either .esc or .enter keys.
/// Prompt is also terminated by .backspace if there is no character left in
/// the input.
fn promptForInput(e: *Editor, prompt: []const u8) !t.Chars {
    var al = try t.Chars.initCapacity(e.alc, 80);

    while (true) {
        // read keys
    }
    e.clearStatusMessage();
    return al;
}
```

This function returns an ArrayList, which is allocated inside the function
itself. It's not a pointer to an existing ArrayList, it's a new one. The caller
must remember to deinitialize this ArrayList with a `defer` statement.

Note that in this case, returning a pointer to the ArrayList created in
`promptForInput()` would mean to return a dangling pointer, so we should
either:

- return a copy (doing this)
- pass a pointer to an existing ArrayList as argument

To be more explicit, we could pass the allocator to `promptForInput()`, but I'm
not doing it here.

### The loop

The loop reads typed characters in the ArrayList. Input is terminated with
<kbd>Esc</kbd> or <kbd>Enter</kbd>, and also with <kbd>Backspace</kbd> if the
prompt is empty. If you wondered if we can move the cursor inside the prompt,
the answer is no. But we can press <kbd>Backspace</kbd> to delete characters.

When pressing <kbd>Esc</kbd> we clear the input characters, otherwise the input
would be accepted, as if we pressed <kbd>Enter</kbd>.

<div class="code-title">Editor.zig: promptForInput() loop</div>

```zig
        try e.statusMessage("{s}{s}", .{ prompt, al.items });
        try e.refreshScreen();

        const k = try ansi.readKey();
        const c = @intFromEnum(k);

        switch (k) {
            .ctrl_h, .backspace => {
                if (al.items.len == 0) {
                    break;
                }
                _ = al.pop();
            },

            .esc => {
                al.clearRetainingCapacity();
                break;
            },

            .enter => break,

            else => if (k == .tab or asc.isPrint(c)) {
                try al.append(e.alc, c);
            },
        }
```

When all is done, we clear the message area with this function, which we'll put
in the Helpers section:

<div class="code-title">Editor.zig</div>

```zig
/// Clear the message area. Can't fail because it won't reallocate.
fn clearStatusMessage(e: *Editor) void {
    e.status_msg.clearRetainingCapacity();
}
```
