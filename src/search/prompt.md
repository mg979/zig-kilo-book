# Updated `promptForInput()`

Remove those assignments at the top:

<div class="code-title">Editor.zig: promptForInput()</div>

<div class="code-diff-removed">

```zig
    _ = cb;
    _ = saved;
```
</div>

Now our prompt function needs to invoke this `PromptCb` callback.

Before the loop starts, we want to define some variables:

<div class="code-title">Editor.zig: promptForInput()</div>

<div class="code-diff-added-top">

```zig
    var k: t.Key = undefined;
    var c: u8 = undefined;
    var cb_args: t.PromptCbArgs = undefined;
```
</div>

```zig
    while (true) {
```

which we'll assign inside the loop:

```zig
    while (true) {
        try e.statusMessage("{s}{s}", .{ prompt, al.items });
        try e.refreshScreen();
```

<div class="code-diff-removed">

```zig
        const k = try ansi.readKey();
        const c = @intFromEnum(k);
```
</div>

<div class="code-diff-added-top">

```zig
        k = try ansi.readKey();
        c = @intFromEnum(k);
        cb_args = .{ .input = &al, .key = k, .saved = saved };
```
</div>

Before the loop ends, we run the callback, if not `null`:

<div class="code-diff-added-top">

```zig
        if (cb) |callback| try callback(e, cb_args);
```
</div>

```zig
    }
    e.clearStatusMessage();
```

After the loop, we call it one last time before returning the input:

<div class="code-diff-removed">

```zig
    e.clearStatusMessage();
    return al;
```
</div>

```zig
    e.clearStatusMessage();
    cb_args.final = true;
    if (cb) |callback| try callback(e, cb_args);
    return al;
```
