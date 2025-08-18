# The Editor type

Create `src/Editor.zig` and let's start adding the struct members. This is an
instantiable module, that's why the filename starts with a capital letter. It's
not enforced, but it's the Zig convention for types to be capitalized.

At the top, we add comments followed by an exclamation mark: it's the module
description. Such special comments may be used for documentation generation.

<div class="code-title">Editor.zig</div>

```zig
//! Type that manages most of the editor functionalities.
//! It draws the main window, the statusline and the message area, and controls
//! the event loop.
```

At the bottom, we put our usual section with constants:

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const Editor = @This();

const std = @import("std");

const t = @import("types.zig");
```

`@This()` is a builtin function that returns the type of the struct. It is
capitalized like all functions that return types. This constant means that in
this file `Editor` refers to the same type we're defining. Others prefer to
name such constants `Self`. I prefer more descriptive names.

## Fields

Back at the top, below the module description, we start adding the type
members:

<div class="code-title">Editor.zig</div>

```zig
/// Allocator used by the editor instance
alc: std.mem.Allocator,
```

We'll use a single allocator for now, the Editor will pass its own to the types
that will require it. We call the field simply `alc`, because it will be passed
so often as argument, that I prefer to keep the name short.

<div class="code-title">Editor.zig</div>

```zig
/// The size of the terminal window where the editor runs
screen: t.Screen,

/// Text buffer the user is currently editing
buffer: t.Buffer,

/// Tracks cursor position and part of the buffer that fits the screen
view: t.View,

/// Becomes true when the main loop should stop, causing the editor to quit
should_quit: bool,
```

We didn't create the `Buffer` nor the `View` type yet.
`should_quit` is the variable that we'll use to control the main event loop.
When this variable becomes true, the loop is interrupted and the program quits.


## Initialization

Now we'll create functions to initialize/deinitialize the editor:

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

/// Return the initialized editor instance.
pub fn init(allocator: std.mem.Allocator, screen: t.Screen) !Editor {
    return .{
        .alc = allocator,
        .screen = .{
            .rows = screen.rows - 2, // make room for statusline/message area
            .cols = screen.cols,
        },
        .buffer = try t.Buffer.init(allocator),
        .view = .{},
        .should_quit = false,
    };
}
```

This is a simple `init()` function that returns a new instance of the Editor.
It's not a _method_ because its first argument is not of type `Editor`.
It is invoked in this way:
```zig
    var editor = Editor.init(allocator, screen);
```
The `deinit()` function, on the other hand, is a proper _method_, because it is
used to deinitialize an instance.

<div class="code-title">Editor.zig</div>

```zig
/// Deinitialize the editor.
pub fn deinit(e: *Editor) void {
    e.buffer.deinit();
}
```

Accordingly, it is invoked like this:

```zig
    editor.deinit();
```

Everything that has used an allocator should be deinitialized here. If you
forget to deinitialize/deallocate something, while still using the
`DebugAllocator`, you'll be told when exiting the program that your program has
leaked memory, and the relative stack trace.

We'll also add a method called `startUp()`. This function will handle the event
loop, and is also called from `main()`.

<div class="code-title">Editor.zig</div>

```zig
/// Start up the editor: open the path in args if valid, start the event loop.
pub fn startUp(e: *Editor, path: ?[]const u8) !void {
    if (path) |name| {
        _ = name;
        // we open the file
    }
    else {
        // we generate the welcome message
    }

    while (e.should_quit == false) {
        // refresh the screen
        // process keypresses
    }
}
```

It's only a stub, but you can see what it should do.

Before continuing the Editor type, we must define the other ones.
