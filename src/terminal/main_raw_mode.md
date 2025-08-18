# Back to main.zig

We left our main function in this state:

<div class="code-title">main.zig</div>

```zig
pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = switch (builtin.mode) {
        .Debug => da.allocator(),
        else => std.heap.smp_allocator,
    };
    _ = allocator;

    var buf: [1]u8 = undefined;
    while (try readChar(&buf) == 1 and buf[0] != 'q') {}
}
```

Now we want to enable raw mode, right? And it's the first thing that our main
function will do. Add these lines at the top of it:

<div class="code-diff-added">

```zig
pub fn main() !void {
```
</div>

```zig
    orig_termios = try linux.enableRawMode();
    defer linux.disableRawMode(orig_termios);
```

The `defer` statement is important because we want to restore the original
configuration when the program exits. We also want to update the bottom section
with our new variables. Add this at the bottom of the file:

```zig
const linux = @import("linux.zig");

var orig_termios: std.os.linux.termios = undefined;
```

```admonish important title="Reminder"
When variables and constants are placed at the root level of a file, that is,
outside any functions, they behave like `static` identifiers in C, only visible
to the code of the current file, unless they have the `pub` qualifier, meaning
they can be accessed from files that import the current one.

Moreover, if the module is meant to be instantiated (it has fields defined at
the root level), these variable and constants are, again, static, not part of
the instances: all instances will share the same value, which is quite obvious
for constants, less so for variables.
```

Why is it important to define `orig_termios` at the root level? Because we want
to handle another case: our program crashes, and we don't want to leave the
terminal in an unusable state if that happens. We'll have to update our crash
handler as well:

<div class="code-diff-added">

```zig
/// Our panic handler disables terminal raw mode and calls the default panic
/// handler.
fn crashed(msg: []const u8, trace: ?usize) noreturn {
```
</div>

```zig
    linux.disableRawMode(orig_termios);
```

As you can see, also this function needs to access the original terminal
configuration, and there's no way to pass it with an argument, it must read it
from a variable.

Now, if you try to build and run the project, something strange happens: the
program terminates immediately.

```admonish note collapsible=true title="Can you guess why?"
Because of the timeout to `read()` in `enableRawMode()`. If you comment out the
two lines where the timeout is set, you can recompile, run, and see that the
prompt keeps reading characters until you press <kbd>q</kbd>, only then it
terminates.
```
