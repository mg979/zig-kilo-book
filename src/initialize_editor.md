# Initialize the editor

Let's open `main.zig` and initialize the editor. Add this to the `main()`
function:

<div class="code-diff-removed">

        _ = allocator;
</div>

```zig
    var e = try t.Editor.init(allocator, try ansi.getWindowSize());
    defer e.deinit();

    var args = std.process.args();
    _ = args.next(); // ignore first arg

    try e.startUp(args.next()); // possible file to open
```

If you remember, the `Editor.init()` function had this signature:

```zig
pub fn init(allocator: std.mem.Allocator, screen: t.Screen) !Editor
```

which means that, besides an allocator, it wants to know the size of the
screen, which is what `getWindowSize()` fetches.

If the `ansi` and `types` modules aren't being imported, add them to the
constants.

<div class="code-title">main.zig</div>

```zig
const t = @import("types.zig");
const ansi = @import("ansi.zig");
```

Next we process the command line arguments, we skip the first one, since it's
the name of our executable, finally we start up the editor passing the second
argument, which could be `null`.
