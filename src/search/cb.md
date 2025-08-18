# The find callback: preparations

We'll have to break the code for the _find_ callback in pieces somehow.

We also need some additional preparations.

### `Pos` type

We need a type that represents a position in the buffer.

<div class="code-title">types.zig</div>

```zig
/// A position in the buffer.
pub const Pos = struct {
    lnr: usize = 0,
    col: usize = 0,
};
```

### `wrapscan` option

We need an option for the searching behavior: should the search continue when
the end of file is reached, by repeating the search from the start of the file?
This also works while searching backwards:

<div class="code-title">option.zig</div>

```zig
/// Searches wrap around the end of the file
pub var wrapscan = true;
```

### Constants

We need two new constants:

<div class="code-title">Editor.zig</div>

```zig
const lastIndexOf = mem.lastIndexOf;
const indexOf = mem.indexOf;
```

