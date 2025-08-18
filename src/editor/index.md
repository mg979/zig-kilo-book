# A text editor

Now we want to turn our text viewer in a proper editor. I guess it's the
natural progression for this kind of things. Not to mention that our guide is
called "_Build a text_ ***editor***", not "_Build a text_ ***viewer***". Let's
not forget that.

Let's start by handling more keypresses in the `processKeypress()` function.

We add new switch prongs for <kbd>Backspace</kbd>, <kbd>Del</kbd> and
<kbd>Enter</kbd>:

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
        .backspace, .ctrl_h, .del => {
            if (k == .del) {
                e.moveCursorWithKey(.right);
            }
            try e.deleteChar();
            e.doCwant(.set);
        },

        .enter => try e.insertNewLine(),
```

We also change our `else` branch to handle characters to be inserted. We only
handle <kbd>Tab</kbd> and printable characters, for now.

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
        else => {
            const c = @intFromEnum(k);
            if (k == .tab or asc.isPrint(c)) {
                try e.insertChar(c);
                e.doCwant(.set);
            }
        },
```

There is a new constant to set:

<div class="code-title">Editor.zig</div>

```zig
const asc = std.ascii;
```

And new functions to implement:

- `insertChar` will insert a character at cursor positin
- `deleteChar` will delete the character on the left of the cursor
- `insertNewLine` will start editing a new line after the current one
