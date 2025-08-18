# Applying the highlight

We have now all we need to apply the highlight. This should be done where rows
are drawn, in `drawRows()`. There, until now, we were simply drawing the
rendered row as-is. This must change into:

We get the portion of the line that starts at `coloff`, and we iterate it for
`len` characters, so that we only iterate the part of the line that can fit the
screen:

<div class="code-title">drawRows() outer loop</div>

<div class="code-diff-removed">

```zig
            if (len > 0) {
                try e.toSurface(rows[ix].render[V.coloff .. V.coloff + len]);
            }
```
</div>

```zig
            // part of the line after coloff, and its highlight
            const rline = if (len > 0) rows[ix].render[V.coloff..] else &.{};
            const hl = if (len > 0) rows[ix].hl[V.coloff..] else &.{};
```

Inside the inner loop we check the character highlight, if it's different, we
apply the highlight attribute, which will remain enabled until a different
highlight is found in the `row.hl` array:

```zig
            var current_color = t.Highlight.normal;

            // loop characters of the rendered row
            for (rline[0..len], 0..) |c, i| {
                if (hl[i] != current_color) {
                    const color = hl[i];
                    current_color = color;
                    try e.toSurface(t.HlGroup.attr(color));
                }
```

We draw the character. At the end of the line we restore default highlight,
otherwise the last highlight would carry over beyond the end of the line, and
onto the next line:

```zig
                try e.toSurface(c);
            }
            // end of the line, reset highlight
            try e.toSurface(ansi.ResetColors);
```

```admonish note title="Safe to iterate zero-length slices?" collapsible=true
We can safely iterate a zero-length slice with a for loop. For example this
just prints `nothing`:

<pre><code class="language-zig">
    const line: []const u8 = &.{};
    for (line) |c| {
        std.debug.print("{}\n", .{c});
        break;
    } else {
        std.debug.print("nothing\n", .{});
    }
</code></pre>

We could not do this with a while loop, because we would need to actually
access the line by index.
```
