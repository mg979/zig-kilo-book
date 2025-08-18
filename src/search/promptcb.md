# The prompt callback

To achieve this, we will need our `promptForInput()` function to accept
a callback function as parameter, and call it repeatedly inside its body.

We define the callback types as follows:

<div class="code-title">types.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Callbacks
//
///////////////////////////////////////////////////////////////////////////////

/// The prompt callback function type
pub const PromptCb = fn (*Editor, PromptCbArgs) EditorError!void;

/// Arguments for the prompt callback
pub const PromptCbArgs = struct {
    /// Current input entered by user
    input: *Chars,

    /// Last typed key
    key: Key,

    /// Saved view, in case it needs to be restored
    saved: View,

    /// Becomes true in the last callback invocation
    final: bool = false,
};
```

Note how easy and clear it is in Zig to define _typedefs_ (as they are named in
C), as we do for `PromptCb`.

Then we change the `promptForInput()` signature to:

<div class="code-diff-removed">

```zig
/// Start a prompt in the message area, return the user input.
/// Prompt is terminated with either .esc or .enter keys.
/// Prompt is also terminated by .backspace if there is no character left in
/// the input.
fn promptForInput(e: *Editor, prompt: []const u8) !t.Chars {
```
</div>

```zig
/// Start a prompt in the message area, return the user input.
/// At each keypress, the prompt callback is invoked, with a final invocation
/// after the prompt has been terminated with either .esc or .enter keys.
/// Prompt is also terminated by .backspace if there is no character left in
/// the input.
fn promptForInput(e: *Editor, prompt: []const u8, saved: t.View, cb: ?t.PromptCb) !t.Chars {
    _ = cb;
    _ = saved;
```

We'll have to fix the previous invocation:

<div class="code-diff-removed">

```zig
        var al = try e.promptForInput(message.prompt.get("fname").?);
```
</div>

```zig
        var al = try e.promptForInput(message.prompt.get("fname").?, .{}, null);
```

