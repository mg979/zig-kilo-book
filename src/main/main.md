# The main.zig file

Every respectable program has an entry point, to let users to actually execute
it and do something with it. Our program is no exception.

Our entry point is located in `src/main.zig`, as we defined it in the
`build.zig` script. The file doesn't have to be named this way, but it must
contain a `main()` function.

```admonish note
I like to have big banners to separate sections of the source code, you don't
have to follow my habits of course, feel free to remove them if you don't like
them.
```

`zig init` created a `src/main.zig`, which we'll have to replace entirely with
this:

<div class="code-title">main.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Main function
//
///////////////////////////////////////////////////////////////////////////////

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = switch (builtin.mode) {
        .Debug => da.allocator(),
        else => std.heap.smp_allocator,
    };
    _ = allocator;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const builtin = @import("builtin");
```

We keep the constants at the bottom of the file, so they don't get too much in
the way. Now they're two, but there's often a whole lot of them.

What we're doing for now is define the allocators we'll be using. Code doesn't
compile if the variables defined in it aren't being used, Zig never likes that.
So for now we have:

    _ = allocator;

after we define the constant.

What this code means, at any rate, is that we use the debug allocator in Debug
mode, and a much faster allocator in proper release modes.

The `builtin.mode` defaults to `.Debug`, so if we simply run

    zig build

it will build the program in debug mode. To use the faster allocator we'll need
to pass an argument, for example:

    zig build -Doptimize=ReleaseSmall # optimize for small binary size
    zig build -Doptimize=ReleaseFast # optimize for performance
    zig build -Doptimize=ReleaseSafe # optimize for safety

But we'll mostly build in debug mode, because if something goes wrong and the
program panics, we'll get the most useful informations about what has caused
the panic, such as array access with index out of bounds (it happened often to
me while writing the program).
