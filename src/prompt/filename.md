# Prompting for a filename

In `saveFile()` we had a placeholder of this case, and we'll replace it with:

<div class="code-title">Editor.zig: saveFile()</div>

<div class="code-diff-removed">

```zig
        // will prompt for a filename
        return;
```
</div>

```zig
        var al = try e.promptForInput(message.prompt.get("fname").?);
        defer al.deinit(e.alc);

        if (al.items.len > 0) {
            B.filename = try e.updateString(B.filename, al.items);
        }
        else {
            try e.statusMessage("Save aborted", .{});
            return;
        }
```

We need a new StringMap in our `message` module:

<div class="code-title">message.zig</div>

```zig
const prompt_messages = .{
    .{ "fname", "Enter filename, or ESC to cancel: " },
};

pub const prompt = std.StaticStringMap([]const u8).initComptime(prompt_messages);
```

### Binding Ctrl-S to save the file

We don't have yet a way to save, because we didn't bind a key. We add a new
branch to the `processKeypress` function:

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
        .ctrl_s => try e.saveFile(),
```

And that's about it. If you compile and run with:

    ./kilo some_new_file

you should be able to edit the file, give it a name and save it.
