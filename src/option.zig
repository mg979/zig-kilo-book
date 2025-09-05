//! Editor options. For now they are hard-coded and cannot be modified from
//! inside the editor, neither are read from a configuration file.

/// Number of spaces a tab character accounts for
pub var tabstop: u8 = 8;

/// Minimal number of screen lines to keep above and below the cursor
pub var scroll_off: u8 = 2;

/// Copy indent from current line when starting a new line
pub var autoindent = true;

/// Searches wrap around the end of the file
pub var wrapscan = true;

/// Wrap text over a new line, when current line becomes longer than this value
pub var textwidth = struct {
    enabled: bool = true,
    len: u8 = 79,
} {};

/// Enable syntax highlighting
pub var syntax = true;

pub const version_str = "0.1";
pub const quit_times = 3;
