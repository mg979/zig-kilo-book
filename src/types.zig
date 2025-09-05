//! Collection of types used by the editor.

///////////////////////////////////////////////////////////////////////////////
//
//                              Editor types
//
///////////////////////////////////////////////////////////////////////////////

/// Dimensions of the terminal screen where the editor runs.
pub const Screen = struct {
    rows: usize = 0,
    cols: usize = 0,
};

pub const Editor = @import("Editor.zig");
pub const Buffer = @import("Buffer.zig");
pub const Row = @import("Row.zig");
pub const View = @import("View.zig");

///////////////////////////////////////////////////////////////////////////////
//
//                              Error sets
//
///////////////////////////////////////////////////////////////////////////////

/// Error set for both read and write operations.
pub const IoError = std.fs.File.OpenError
                 || std.fs.File.WriteError
                 || std.Io.Reader.Error
                 || std.Io.Writer.Error;

///////////////////////////////////////////////////////////////////////////////
//
//                              Other types
//
///////////////////////////////////////////////////////////////////////////////

/// A dynamical string.
pub const Chars = std.ArrayList(u8);

/// ASCII codes of the keys, as they are read from stdin.
pub const Key = enum(u8) {
    ctrl_b = 2,
    ctrl_c = 3,
    ctrl_d = 4,
    ctrl_f = 6,
    ctrl_g = 7,
    ctrl_h = 8,
    tab = 9,
    ctrl_j = 10,
    ctrl_k = 11,
    ctrl_l = 12,
    enter = 13,
    ctrl_q = 17,
    ctrl_s = 19,
    ctrl_t = 20,
    ctrl_u = 21,
    ctrl_z = 26,
    esc = 27,
    backspace = 127,
    left = 128,
    right = 129,
    up = 130,
    down = 131,
    del = 132,
    home = 133,
    end = 134,
    page_up = 135,
    page_down = 136,
    _,
};

/// Controls handling of the wanted column.
pub const Cwant = enum(u8) {
    /// To set cwant to a new value
    set,
    /// To restore current cwant, or to the last column if too big
    restore,
    /// To set cwant to maxUsize, which means 'always the last column'
    maxcol,
};

///////////////////////////////////////////////////////////////////////////////
//
//                              Highlight
//
///////////////////////////////////////////////////////////////////////////////

/// All available highlight types.
pub const Highlight = enum(u8) {
    /// The normal highlight
    normal = 0,

    /// Incremental search highlight
    incsearch,

    /// Highlight for non-printable characters
    nonprint,

    /// Highlight for error messages
    err,
};

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

    /// Get the attribute of a HlGroup from the hlAttrs array.
    pub fn attr(color: Highlight) []const u8 {
        return hlAttrs[@intFromEnum(color)];
    }
};

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

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const hlAttrs = @import("hlgroups.zig").hlAttrs;
