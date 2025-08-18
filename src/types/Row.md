# The Row type

Description at the top:

<div class="code-title">Row.zig</div>

```zig
//! A Row contains 3 arrays, one for the actual characters, one for how it is
//! rendered on the screen, and one with the highlight of each element of the
//! rendered array.
```

Constants:

<div class="code-title">Row.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const Row = @This();

const std = @import("std");

const t = @import("types.zig");

const initial_row_size = 80;
```

Also for this type, we keep it simple: no operations are performed by it. We
will add more things to this type as soon as we need them, this is only
a partial implementation.

<div class="code-title">Row.zig</div>

```zig
/// The ArrayList with the actual row characters
chars: t.Chars,

/// Array with the visual representation of the row
render: []u8,

///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

pub fn init(allocator: std.mem.Allocator) !Row {
    return Row{
        .chars = try .initCapacity(allocator, initial_row_size),
        .render = &.{},
    };
}

pub fn deinit(row: *Row, allocator: std.mem.Allocator) void {
    row.chars.deinit(allocator);
    allocator.free(row.render);
}
```

Some explanations:

- our `chars` field is a dynamic string, it contains the actual characters of
the row, it expands or shrinks as characters are typed/deleted. We set an
initial capacity, to reduce the need for later allocations.

- the `render` field is a simple array of `u8`. This is probably not optimal,
but we'll see later if we can improve the implementation. The point is that
this array doesn't need to grow dynamically, when it is updated its new size
can be precalculated, so at most it would need a single reallocation, which may
result in no new allocation at all. For now we keep it simple.

- as usual, the `init()` function returns a new instance, the `deinit()` method
frees the memory.

We also add some methods that will help us keeping code concise:

<div class="code-title">Row.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Methods
//
///////////////////////////////////////////////////////////////////////////////

/// Length of the real row.
pub fn clen(row: *Row) usize {
    return row.chars.items.len;
}

/// Length of the rendered row.
pub fn rlen(row: *Row) usize {
    return row.render.len;
}
```

```admonish note title="Zero-length initialization"
In this line

<pre class="code-block-small"><code class="language-zig">.render = &.{},
</code></pre>

you might wonder why that notation: `&.{}`. It's a _zero-length_ slice. The
[official documentation](https://ziglang.org/documentation/0.15.1/#Slices)
says:

<pre class="code-block-small"><code>A zero-length initialization can always be used to create an empty slice,
even if the slice is mutable. This is because the pointed-to data is zero
bits long, so its immutability is irrelevant.
</code></pre>

It's different from initializing a slice to `undefined`, because here the slice
has a known length, which is `0`. So you can loop it safely, provided that
you check its length and don't access any index, since it's empty.

<pre class="code-block-small"><code class="language-zig">for (&.{}) |c| {} // ok
</code></pre>

I think it's always preferable to initialize a slice this way, rather than with
`undefined`.
```
