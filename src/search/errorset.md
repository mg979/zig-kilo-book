# `EditorError` set

If you try to compile now, the compiler will tell you that this error doesn't
exist. If you try to remove it from the `PromptCb` return value, the compiler
will tell you

    error: function type cannot have an inferred error set

So we need an explicit error set for our callback. We don't know how many kinds
of errors could cause a `PromptCb` to fail. The callback we'll be using for the
searching function will be of type

    error{OutOfMemory}

So we could just write that. But `PromptCb` is a 'generic' callback, which
could do just about anything, and we'd need to add more errors to that set.

Instead, we create our `EditorError` set, and if we'll need to handle more
errors, we'll add them to this set.

Just add it above our previous `IoError` set:

<div class="code-title">types.zig</div>

```zig
/// Error set for functions requiring explicit error handling.
pub const EditorError = error{
    OutOfMemory,
};
```
