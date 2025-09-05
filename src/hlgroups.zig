///////////////////////////////////////////////////////////////////////////////
//
//                              Highlight groups
//
///////////////////////////////////////////////////////////////////////////////

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
