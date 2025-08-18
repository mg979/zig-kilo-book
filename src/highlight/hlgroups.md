# Highlight groups

Highlight groups have properties, which we define in a new type.

<div class="code-title">types.zig</div>

```zig
/// Attributes of a highlight group.
pub const HlGroup = struct {
    /// Foreground CSI color code
    fg: u8,

    /// Background CSI color code
    bg: u8,

    reverse: bool,
    bold: bool,
    italic: bool,
    underline: bool,
};
```

### An array of highlight groups

We create the array with the highlight groups in a new module `hlgroups.zig`,
since an array isn't a __Type__.

We add already a helper to get the index for the array when initializing it.

<div class="code-title">hlgroups.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Highlight groups
//
///////////////////////////////////////////////////////////////////////////////

// here goes the hlGroups array

// Get the enum value as integer, so that it can be used as array index.
fn int(ef: t.Highlight) usize {
    return @intFromEnum(ef);
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const t = @import("types.zig");

const ansi = @import("ansi.zig");
const CSI = ansi.CSI;
const FgColor = ansi.FgColor;
const BgColor = ansi.BgColor;
```

Here things become really interesting, so pay attention.

We must define an array of highlight groups. There are no designated
initializers in Zig, so we use a [_labeled
block_](https://ziglang.org/documentation/0.15.1/#Blocks) to make up for them.
At the same time, you'll see that these blocks let us do some wondrous things.

This block must return an array of `HlGroup`, with a size that is the number of
the fields of the `Highlight` enum. We don't want to guess how many highlight
types we have, so we get the exact number of them. We can do so with:

    @typeInfo(EnumType).@"enum".fields.len

```admonish note title="@\\" notation for identifiers" collapsible=true
From the [official
documentation](https://ziglang.org/documentation/0.15.1/#Identifiers):

    Variable identifiers are never allowed to shadow identifiers from an outer
    scope. Identifiers must start with an alphabetic character or underscore
    and may be followed by any number of alphanumeric characters or
    underscores. They must not overlap with any keywords.

If an identifier wouldn't be valid according to this rules, we can use the `@"`
notation. In our case we write `@"enum"` because `enum` is a keyword.
```

<div class="code-title">hlgroups.zig</div>

```zig
// Number of members in the Highlight enum
const n_hl = @typeInfo(t.Highlight).@"enum".fields.len;

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
    hlg[int(.incsearch)] = .{
        .fg = FgColor.green,
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

### An array of highlight attributes

We also define an array with the _attributes_ (the generated CSI sequences) for
all highlight groups. Also this one is created with a labeled block.

In this last block there's a loop: from the previously defined highlight
groups, it will generate the CSI escape sequence (the attribute) of the group
itself. This sequence is what we will actually use in the program to apply the
highlight.

<div class="code-title">hlgroups.zig</div>

```zig
/// Array with highlight attributes.
pub const hlAttrs: [n_hl][]const u8 = arr: {
    // generate the attribute for each of the highlight groups
    // bold/italic/etc: either set them, or reset them to avoid their
    // propagation from previous groups
    var hla: [n_hl][]const u8 = undefined;
    for (hlGroups, 0..) |hlg, i| {
        hla[i] = CSI ++ std.fmt.comptimePrint("{s}{s}{s}{s}{};{}m", .{
            if (hlg.bold) "1;" else "22;",
            if (hlg.italic) "3;" else "23;",
            if (hlg.underline) "4;" else "24;",
            if (hlg.reverse) "7;" else "27;",
            hlg.fg,
            hlg.bg,
        });
    }
    break :arr hla;
};
```

Maybe you didn't realize yet why it's so awesome: everything here is done at
compile time! There won't be trace of this in the binary executable, except the
resulting `hlAttrs` array. The block doesn't use the `comptime` keyword, if you
use it the compiler will tell you

    error: redundant comptime keyword in already comptime scope

As proof that the `comptime` keyword is unnecessary most of the times.

```admonish note
The `hlGroups` array isn't used at runtime. Still, defining it is useful
because we can change more easily the highlight groups. The compiler keeps out
of the executable what isn't used at runtime anyway.
```

### How we access the attribute

We'll create a method in the `HlGroup` type that returns the attribute for that
highlight type:

<div class="code-title">types.zig: HlGroup</div>

```zig
    underline: bool,
```

<div class="code-diff-added-top">

```zig
    /// Get the attribute of a HlGroup from the hlAttrs array.
    pub fn attr(color: Highlight) []const u8 {
        return hlAttrs[@intFromEnum(color)];
    }
```
</div>

And import the array:

<div class="code-title">types.zig</div>

```zig
const hlAttrs = @import("hlgroups.zig").hlAttrs;
```

```admonish note title="CSI escape sequences" collapsible=true

The _attribute_ of each highlight group is a string: the escape sequence that
is fed to the terminal to get the highlight we want. The format is:

    ESC[{bold};{italic};{underline};{reverse};{fg-color};{bg-color}m

For example, if a group wants bold text, it will start with

    \x1b[1;

If it doesn't want it, it will reset the bold attribute with

    \x1b[22;

Otherwise it would inherit the value of the group that preceded it, whatever it
was.
```
