# The View type

This type only contains fields. This is the full type, nothing more will be
added. It tracks the cursor position and the portion of the buffer that is
shown in the main window.

<div class="code-title">View.zig</div>

```zig
//! A View of the current buffer is what we can see of it, and where the
//! cursor lies in it. It's basically the editor window where the file is
//! shown.

/// cursor column
cx: usize = 0,

/// cursor line
cy: usize = 0,

/// column in the rendered row
rx: usize = 0,

/// wanted column when moving vertically across shorter lines
cwant: usize = 0,

/// the top visible line, increases as we scroll down
rowoff: usize = 0,

/// the leftmost visible column
coloff: usize = 0,
```
