# The Buffer type

Description at the top:

<div class="code-title">Buffer.zig</div>

```zig
//! A Buffer holds the representation of a file, divided in rows.
//! If modified, it is marked as dirty until saved.
```

Let's add the constants: as usual, they'll stay at the bottom.

Also here we set a constant to `@This()`, so that we can refer to our type
inside its own definition.

<div class="code-title">Buffer.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const Buffer = @This();

const std = @import("std");
const t = @import("types.zig");

/// Initial allocation size for Buffer.rows
const initial_rows_capacity = 40;
```

## Fields

Also in this case, as you can see, no default initializers.

Some members are _optional_, meaning that they can be `null`, and `null` will
be their initial value when the Buffer is initialized.

<div class="code-title">Buffer.zig</div>

```zig
alc: std.mem.Allocator,

// Modified state
dirty: bool,

// Buffer rows
rows: std.ArrayList(t.Row),

// Path of the file
filename: ?[]u8,

// Name of the syntax
syntax: ?[]const u8,
```

## Initialization

All in all, this type is quite simple. It doesn't handle single row
initialization, because rows are created and inserted by the Editor, but it
will deinitialize them. Possibly I'm doing a questionable choice here, maybe
I should let the Buffer initialize the single rows, since it's here that
they're freed at last. Especially if we intend to give a Buffer its own
different allocator (an `arena` allocator probably would fit it best). But it's
a small detail, since the Editor can access the `Buffer` allocator just fine,
since there are no private fields in Zig.

<div class="code-title">Buffer.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

pub fn init(allocator: std.mem.Allocator) !Buffer {
    return Buffer{
        .alc = allocator,
        .rows = try .initCapacity(allocator, initial_rows_capacity),
        .dirty = false,
        .filename = null,
        .syntax = null,
    };
}

pub fn deinit(buf: *Buffer) void {
    t.freeOptional(buf.alc, buf.filename);
    t.freeOptional(buf.alc, buf.syntax);
    for (buf.rows.items) |*row| {
        row.deinit(buf.alc);
    }
    buf.rows.deinit(buf.alc);
}
```

There is one new function, `freeOptional()`, which we didn't define yet.
It's a simple helper, but it doesn't harm to have some helper functions.
I put it in the `types` module, right above the bottom section:

<div class="code-title">types.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Free an optional slice if not null.
pub fn freeOptional(allocator: std.mem.Allocator, sl: anytype) void {
    if (sl) |slice| {
        allocator.free(slice);
    }
}
```

```admonish note
I put this function here only because the `types` module is accessed by most
other modules, so it's easily accessible. But since it doesn't return
a __Type__, I think it's slightly misplaced.
```
