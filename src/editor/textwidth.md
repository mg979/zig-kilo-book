# Handling text wrapping

There's one last thing that we should handle, one little thing that will make
our editor much more usable.

After we type a certain number of characters in the line, we want our text to
be automatically wrapped into a new line, to avoid that the line becomes too
long.

We call this option `textwidth` and we add it to our `option` module.

<div class="code-title">option.zig</div>

```zig
/// Wrap text over a new line, when current line becomes longer than this value
pub var textwidth = struct {
    enabled: bool = true,
    len: u8 = 79,
} {};
```

Thinking more about it, it's not always desirable, especially when writing
code. Our implementation will be particularly stubborn and absolutely refuse to
let us write differently. In the future we might introduce ways to change
option values with key combinations, and allow different options for different
filetypes. For now, this is it, and we must accept it.

We need a new `string` module function:

<div class="code-title">string.zig</div>

```zig
/// Return true if `c` is a word character.
pub fn isWord(c: u8) bool {
    return switch (c) {
        '0'...'9', 'a'...'z', 'A'...'Z', '_' => true,
        else => false,
    };
}
```

Handling of text wrapping happens in `insertChar()`, right after inserting the
character.

<div class="code-title">Editor.zig: insertChar()</div>


```zig
    // insert the character and move the cursor forward
    try e.rowInsertChar(V.cy, V.cx, c);
    V.cx += 1;
```

<div class="code-diff-added-top">

```zig
    //////////////////////////////////////////
    //              textwidth
    //////////////////////////////////////////

    const row = e.currentRow();
    const rx = row.cxToRx(V.cx);

    if (opt.textwidth.enabled and rx > opt.textwidth.len and str.isWord(c)) {
```
</div>

The logic can be split in two phases.

### Phase 1

<div class="numbered-table">

| | |
|-|-|
| • | we must find the start of the current word, crawling back along the current row |
| • | if this word is preceded by a space character, we push back the cursor again, because we want to remove a single space while wrapping text, but not more than one |
| • | if this word is preceded by another kind of separator, we don't remove it, we just wrap the word |

<div class="code-title">Editor.zig: insertChar()</div>

```zig
        // will be 1 if a space before the wrapped word must be removed
        var skipw: usize = 0;

        // find the start of the current word
        var start: usize = rx - 1;

        while (start > 0) {
            if (!str.isWord(row.render[start - 1])) {
                // we want to remove a space before the wrapped word, but not
                // other kinds of separators (not even a tab, just in case)
                if (row.render[start - 1] == ' ') {
                    skipw = 1;
                }
                break;
            }
            start -= 1;
        }
```

### Phase 2

We crawled back in the row, and we found where this word began. If the column
is 0, it means it's a single very long sequence of _word_ characters, we can't
wrap anything.

If instead we can wrap it, we proceed as follows:

| | |
|-|-|
| • | we set the cursor before the word, and also before the space character that precedes it (if there is one) |
| • | we insert a new line: the same things that would happen when pressing <kbd>Enter</kbd> would happen now, the extra space would be deleted and the word would be carried to the new line |
| • | we move forward the cursor to the end of the word we wrapped |




<div class="code-title">Editor.zig: insertChar()</div>

```zig
        // only wrap if the word doesn't start at the beginning
        if (start > 0) {
            const wlen = rx - start;

            // move the cursor to the start of the word, also skipping a space
            V.cx = row.rxToCx(start - skipw);

            // new line insertion will carry over the word and delete the space
            try e.insertNewLine();

            // move forward the cursor to the end of the word
            V.cx += wlen;
        }
    }
```

This completes the _editor_ chapter. We still can't save our edits, but before
getting there we need to expand the capabilities of our message area, so that
it can actually print something.
