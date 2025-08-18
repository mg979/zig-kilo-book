# Panic handler

Speaking of panic, we want to add our own panic handler. Normally, if the
program panics, it will crash and invoke the default panic handler, which
prints a stack trace about the error. We'll need more than that, so we change
the panic handler to our own:

<div class="code-title">main.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Panic handler
//
///////////////////////////////////////////////////////////////////////////////

pub const panic = std.debug.FullPanic(crashed);

fn crashed(msg: []const u8, trace: ?usize) noreturn {
    std.debug.defaultPanic(msg, trace);
}
```

Since we don't need it for anything yet, what it does is simply to call the
default panic handler, passing the same arguments it receives.

You may have noticed that strange return type: `noreturn`. It means the
function doesn't simply return anything, like a `void` would do, it doesn't
return at all. This is so because when this function is called, our program has
crashed already, and it couldn't return any value anyway. You shouldn't worry
about it because it's the first and last time we'll see it in our program.

```admonish note title="What's panic anyway?"
When the program encounters an error at runtime, depending on the kind of
error, two things may happen:

- the program crashes (best case)
- the program keeps running, but its state is corrupted (worst case)

In the second case really nasty things can happen, so we want to avoid bugs at
all costs. In _safe_ release modes (Debug and ReleaseSafe), events that would
normally cause a crash or undefined behavior cause _panic_ instead. The program
terminates and you get a meaningful stack trace of what has caused the error.
```
