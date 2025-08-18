# New string functions

We'll complete our `string` module with a new set of functions that we'll use
for syntax highlighting.

### str.eql

We could just call `mem.eql(u8, ...)` everywhere. It's just a shorthand.
I don't know it's good practice, but we'll call it many times and the meaning
is immediately obvious, so it's ok for me.

<div class="code-title">string.zig</div>

```zig
/// Return `true` if slices have the same content.
pub fn eql(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}
```

### str.isTail

This is used for filetype detection.

<div class="code-title">string.zig</div>

```zig
/// Return `true` if the tail of haystack is exactly `needle`.
pub fn isTail(haystack: []const u8, needle: []const u8) bool {
    const idx = mem.lastIndexOfLinear(u8, haystack, needle);
    return idx != null and idx.? + needle.len == haystack.len;
}
```

### str.getExtension

Also used for filetype detection.

<div class="code-title">string.zig</div>

```zig
/// Get the extension of a filename.
pub fn getExtension(path: []u8) ?[]u8 {
    const ix = mem.lastIndexOfScalar(u8, path, '.');
    if (ix == null or ix == path.len - 1) {
        return null;
    }
    return path[ix.? + 1 ..];
}
```

### str.isSeparator

This one is very similar to `str.isWord`. It's actually the opposite. I only
make it a different function to be able to check whitespace before other
characters, since whitespace is the most common way to separate words, and
should be prioritized when deciding if something is a separator or not.

But I'm not sure it really makes a difference. If it doesn't, this function
should be removed and  
`!str.isWord()` would be used instead.

<div class="code-title">string.zig</div>

```zig
/// Return true if character is a separator (not a word character).
pub fn isSeparator(c: u8) bool {
    if (c == ' ' or c == '\t') return true;
    return switch (c) {
        '0'...'9', 'a'...'z', 'A'...'Z', '_' => false,
        else => true,
    };
}
```
