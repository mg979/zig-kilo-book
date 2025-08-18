# Syntax highlighting

The last feature to implement is syntax highlighting.

### New fields

Add a new field in the `Buffer` type:

<div class="code-title">Buffer.zig</div>

```zig
// Pointer to the syntax definition
syndef: ?*const t.Syntax,
```

And one in the `Row` type:

<div class="code-title">Row.zig</div>

```zig
/// True when the row has a multiline comment continuing into next line
ml_comment: bool,
```

This one becomes true when a line contains the leader that opens the multi-line
comment, and stays true in all following rows, until the end of the block is
found, in that row it becomes false again.

```admonish important title="Reminder"
Initialize both in their relative `init()`, to `null` and `false` respectively.
Add imports where necessary.
```

### Fill the rest of Highlight enum

This is the full Highlight enum, with all needed highlight names:

<div class="code-title">types.zig</div>

```zig
/// All available highlight types.
pub const Highlight = enum(u8) {
    /// The normal highlight
    normal = 0,

    /// Line comments highlight
    comment,

    /// Multiline comments highlight
    mlcomment,

    /// Numbers highlight
    number,

    /// String highlight
    string,

    /// Highlight for keywords of type 'keyword'
    keyword,

    /// Highlight for keywords of type 'types'
    types,

    /// Highlight for keywords of type 'builtin'
    builtin,

    /// Highlight for keywords of type 'constant'
    constant,

    /// Highlight for keywords of type 'preproc'
    preproc,

    /// Highlight for uppercase words
    uppercase,

    /// Highlight for escape sequences in strings
    escape,

    /// Incremental search highlight
    incsearch,

    /// Highlight for non-printable characters
    nonprint,

    /// Highlight for error messages
    err,
};
```

### Fill the rest of hlGroups array

This the full initializer of the `hlGroups` array, replace the previous one
with it.

<div class="code-title">hlgroups.zig</div>

```zig
/// Array with highlight groups.
pub const hlGroups: [n_hl]t.HlGroup = arr: {
    // Initialize the hlGroups array at compile time. A []HlGroup array is
    // first declared undefined, then it is filled with all highlight groups.
    var hlg: [n_hl]t.HlGroup = undefined;
    hlg[int(.normal)] = .{
        .fg = FgColor.default,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.comment)] = .{
        .fg = FgColor.black_bright,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.mlcomment)] = .{
        .fg = FgColor.blue_bright,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.number)] = .{
        .fg = FgColor.white_bright,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.string)] = .{
        .fg = FgColor.green,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.keyword)] = .{
        .fg = FgColor.cyan,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.types)] = .{
        .fg = FgColor.cyan_bright,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.builtin)] = .{
        .fg = FgColor.magenta,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.constant)] = .{
        .fg = FgColor.yellow,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.preproc)] = .{
        .fg = FgColor.red_bright,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.uppercase)] = .{
        .fg = FgColor.yellow_bright,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.escape)] = .{
        .fg = FgColor.red,
        .bg = BgColor.default,
        .reverse = false,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.incsearch)] = .{
        .fg = FgColor.green,
        .bg = BgColor.default,
        .reverse = true,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.nonprint)] = .{
        .fg = FgColor.white,
        .bg = BgColor.default,
        .reverse = true,
        .bold = false,
        .italic = false,
        .underline = false,
    };
    hlg[int(.err)] = .{
        .fg = FgColor.red_bright,
        .bg = BgColor.default,
        .reverse = false,
        .bold = true,
        .italic = false,
        .underline = false,
    };
    break :arr hlg;
};
```
