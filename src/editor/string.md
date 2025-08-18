# The string module

Before we proceed, let's add a new module called `string.zig`. It will be quite
simple, just a few helpers for string operations.

It will contain a single function for now. Don't forget to import in Editor.

<div class="code-title">string.zig</div>

```zig
//! Module with functions handling strings.

///////////////////////////////////////////////////////////////////////////////
//
//                              Functions
//
///////////////////////////////////////////////////////////////////////////////

/// Return the number of leading whitespace characters
pub fn leadingWhitespaces(src: []u8) usize {
    var i: usize = 0;
    while (i < src.len and asc.isWhitespace(src[i])) : (i += 1) {}
    return i;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const asc = std.ascii;
const mem = std.mem;
```
