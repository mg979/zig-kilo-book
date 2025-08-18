# Syntax types

You can either defined them in `types` module (which I do) or in a different
file, which will be imported by the `types` module, so that it's accessible
also from there.

## The Syntax type

This type defines many properities of a syntax: extensions used for filetype
detection, comment leaders, keywords and syntax-specific editor options.

<div class="code-title">types.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Syntax types
//
///////////////////////////////////////////////////////////////////////////////

pub const Syntax = struct {
    /// Name of filetype
    ft_name: []const u8,

    /// Array of extensions for filetype detection
    ft_ext: []const []const u8,

    /// Array of names for filetype detection, to be matched against the tail
    /// of any path, so for example ".git/config" will match against any git
    /// configuration file in any directory.
    ft_fntails: []const []const u8,

    /// Leaders for single-line comments
    lcmt: []const []const u8,

    /// Array with multiline comment leaders
    /// [0] is start of block
    /// [1] is leader for lines between start and end
    /// [2] is end of block
    mlcmt: ?[3][]const u8,

    /// Array of words with 'Keywords' highlight
    keywords: []const []const u8,

    /// Array of words with 'Types' highlight
    types: []const []const u8,

    /// Array of words with 'Builtin' highlight
    builtin: []const []const u8,

    /// Array of words with 'Constant' highlight
    constant: []const []const u8,

    /// Array of words with 'Preproc' highlight
    preproc: []const []const u8,

    /// Bit field with supported syntax groups
    flags: SyntaxFlags,
};
```

## The syntax flags

This type is important because it controls the kinds of highlight that a syntax
supports, that is what the syntax highlighter will actually highlight when
parsing the buffer.

<div class="code-title">types.zig</div>

```zig
pub const SyntaxFlags = packed struct {
    /// Should highlight integer and floating point numbers
    numbers: bool = false,

    /// Should highlight 0x[0-9a-fA-F]+ numbers
    hex: bool = false,

    /// Should highlight 0b[01]+ numbers
    bin: bool = false,

    /// Should highlight 0o[0-7]+ numbers
    octal: bool = false,

    /// Supports undescores in numeric literals
    uscn: bool = false,

    /// Should highlight strings
    strings: bool = false,

    /// Supports double-quoted strings
    dquotes: bool = false,

    /// Supports single-quoted strings
    squotes: bool = false,

    /// Highlight backticks as strings
    backticks: bool = false,

    /// Single-quotes are used for char literals instead
    chars: bool = false,

    /// Should highlight uppercase words
    uppercase: bool = false,
};
```
