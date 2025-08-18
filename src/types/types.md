# The editor types

Now it's time for the first steps towards the creation of our editor.

The original C code of `kilo` is single-file, with a global variable `E` that
holds the Editor _struct_, and all functionalities are implemented there.
Initially I wrote this program pretty much in the same way, and it worked, as
a demonstration that you can write code in Zig that uses global variables, just
as in old-fashioned C programs.

In Zig you can also (and probably should) use instantiable types, which then
are used in a OOP fashion by omitting the first argument when this is of the
same type, either passed by reference or by value. You should know this
already, so I won't elaborate.

It may be useful to remind that a Zig module is essentially a `struct`, that
is, you can think the content of a file as wrapped in

```zig
struct {
    // the file content
}
```

which means that we can define at the root level of a file the members of our
type, then treat the whole file as an instantiable type. That's what we'll do
with the main types of our editor, which will be:


| | |
|----------|----------|
| **Editor**         |  for the editor functionalities        |
| **Buffer** | for the file contents |
| **Row** | each row of the buffer |
| **View** | tracks cursor position and offsets of the editing window |

To keep the code simple, we'll code most functionalities in the Editor type,
while the others will be lightweight structs that never modify the state of the
editor.

## The `types` module holds all our types

Even though each of these types will have its own importable module, all other
modules will access them through the `src/types.zig` module, that serves as
a centralized hub for all our types.

We can do this because the program is small, but probably it wouldn't be a wise
thing to do in a large program. Still, also the Zig standard library often
makes types defined in submodules accessible from the root module. An example
is `std.ArrayList`.

We'll do it right away, open the `types` module and add this below the `Screen`
definition:

<div class="code-title">types.zig</div>

```zig
pub const Editor = @import("Editor.zig");
pub const Buffer = @import("Buffer.zig");
pub const Row = @import("Row.zig");
pub const View = @import("View.zig");
```

The files don't exist yet, but we'll create them soon. We'll build up the types
little by little, adding more stuff only when we need it.

We also create a section for other miscellaneous types:

<div class="code-title">types.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Other types
//
///////////////////////////////////////////////////////////////////////////////

/// A dynamical string.
pub const Chars = std.ArrayList(u8);
```

And the usual Constants section:

<div class="code-title">types.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
```
