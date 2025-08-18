# More escape sequences

We also add a bunch of constants to the bottom of `ansi.zig`. These are escape
sequences that we'll use while drawing, at one point or another, so let's just
add them all now:

<div class="code-title">ansi.zig</div>

```zig
/// Background color
pub const BgDefault = CSI ++ "40m";

/// Foreground color
pub const FgDefault = CSI ++ "39m";

/// Hide the terminal cursor
pub const HideCursor = CSI ++ "?25l";

/// Show the terminal cursor
pub const ShowCursor = CSI ++ "?25h";

/// Move cursor to position 1,1
pub const CursorTopLeft = CSI ++ "H";

/// Start reversing colors
pub const ReverseColors = CSI ++ "7m";

/// Reset colors to terminal default
pub const ResetColors = CSI ++ "m";

/// Clear the content of the line
pub const ClearLine = CSI ++ "K";

/// Color used for error messages
pub const ErrorColor = CSI ++ "91m";
```
