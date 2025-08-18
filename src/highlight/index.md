# Highlight

We have two features left to implement: searching and syntax highlighting.
Both of them require the ability to apply a different highlight to our text, so
we'll do that.

We'll do everything in the `types` module, but first we must define the color
codes that we'll be using. In `ansi` define these namespaced constants:

<div class="code-title">ansi.zig</div>

```zig
/// Codes for 16-colors terminal escape sequences (foreground)
pub const FgColor = struct {
    pub const default: u8 = 39;
    pub const black: u8 = 30;
    pub const red: u8 = 31;
    pub const green: u8 = 32;
    pub const yellow: u8 = 33;
    pub const blue: u8 = 34;
    pub const magenta: u8 = 35;
    pub const cyan: u8 = 36;
    pub const white: u8 = 37;
    pub const black_bright: u8 = 90;
    pub const red_bright: u8 = 91;
    pub const green_bright: u8 = 92;
    pub const yellow_bright: u8 = 93;
    pub const blue_bright: u8 = 94;
    pub const magenta_bright: u8 = 95;
    pub const cyan_bright: u8 = 96;
    pub const white_bright: u8 = 97;
};

/// Codes for 16-colors terminal escape sequences (background)
pub const BgColor = struct {
    pub const default: u8 = 49;
    pub const black: u8 = 40;
    pub const red: u8 = 41;
    pub const green: u8 = 42;
    pub const yellow: u8 = 43;
    pub const blue: u8 = 44;
    pub const magenta: u8 = 45;
    pub const cyan: u8 = 46;
    pub const white: u8 = 47;
    pub const black_bright: u8 = 100;
    pub const red_bright: u8 = 101;
    pub const green_bright: u8 = 102;
    pub const yellow_bright: u8 = 103;
    pub const blue_bright: u8 = 104;
    pub const magenta_bright: u8 = 105;
    pub const cyan_bright: u8 = 106;
    pub const white_bright: u8 = 107;
};
```
