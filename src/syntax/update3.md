# Multi-line comments

```admonish note
Remember that we had, when defining constants and variables:

<pre class="code-block-small"><code class="language-zig">// line is in a multiline comment
var in_mlcomment = ix > 0 and e.buffer.rows.items[ix - 1].ml_comment;
</code></pre>
```

#### we have ML comments...

Our `mlcmt` field is an optional field, so we must check if it's `null`.
If not `null`, it's a `[3]u8` array with start marker, middle marker and
end marker.

```zig
        // ML comments
        if (mlc != null and mlc.?.len > 0 and !in_string) {
            const mc = mlc.?;
```

#### we are in a ML comment...

... this we can know because `in_mlcomment` is true if the previous row's
`ml_comment` field is true.

In this case we paint the character as ML comment, and keep looking for the end
marker.

```zig
            if (in_mlcomment) {
                const len = mc[2].len;
                row.hl[i] = t.Highlight.mlcomment;
```

#### we do find the end marker...

... then `in_mlcomment` becomes false. After the marker, normal parsing resumes
in this row.

```admonish note
We don't _break_ out of the top-level loop, we _continue_ it, because unlike
line comments, multi-line ones can end in the same line where they started.
```

```zig
                if (i + len <= rowlen and str.eql(row.render[i .. i + len], mc[2])) { // END
                    @memset(row.hl[i .. i + len], t.Highlight.mlcomment);
                    i += len;
                    in_mlcomment = false;
                    prev_sep = true;
                    continue :toplevel;
                }
```

#### we don't find the end marker...

... then `in_mlcomment` keeps being true also for this line. We keep painting
everything as ML comment.

```zig
                else {
                    i += 1;
                    continue :toplevel;
                }
            }
```

#### we aren't in a ML comment yet...

... and we find the start marker. `in_mlcomment` becomes true. From then
onwards, characters are painted as ML comment.

```zig
            else {
                const len = mc[0].len;

                if (i + len <= rowlen and str.eql(row.render[i .. i + len], mc[0])) { // START
                    @memset(row.hl[i .. i + len], t.Highlight.mlcomment);
                    i += len;
                    in_mlcomment = true;
                    continue :toplevel;
                }
            }
        }
```

Following row will have `in_mlcomment` set to false.

### A change in comment state triggers a chain update

Normally we only update the row that has changed, but for multi-line patterns,
we must update following rows too, otherwise their highlight would stay the
same.

We must keep updating following rows, until the value of `in_mlcomment` matches
the value of `row.ml_comment`: only in this case we know that the row wasn't
affected by the multi-line pattern. Only then we can stop the chain of row
updates.

This is done at the very bottom of the `updateHighlight` function. Add it now,
so that you can have a clearer picture.

<div class="code-title">Editor.zig: bottom of updateHighlight()</div>

```zig
    // If a multiline comment state has changed (either a comment started, or
    // a previous one has been closed) we must update following the row, which
    // will in turn update others, until all rows affected by the comment are
    // updated.
    const mlc_state_changed = row.ml_comment != in_mlcomment;
    row.ml_comment = in_mlcomment;
    if (mlc_state_changed and ix + 1 < e.buffer.rows.items.len) {
        try e.updateHighlight(ix + 1);
    }
```

If you still didn't get it, imagine 10 rows, no ML comments. Their
`row.ml_comment` is false.

<div class="numbered-table-no-bar">

| | |
|-|-|
| 1. | if ML comment starts at line 2, `in_mlcomment` becomes true |
| 2. | `in_mlcomment` is different from `row.ml_comment` and it triggers the chain update |
| 3. | following row has `in_mlcomment` set to true, because it's equal to `row.ml_comment` of previous row |
| 4. | it's different from its own `row.ml_comment`, chain update continues |
| 5. | all following lines become commented this way, all their `row.ml_comment` becomes true |
| 6. | now you insert the end marker at line 4 |
| 7. | you trigger another chain update, which reverses the state of the lines that follow |
</div>

```admonish note
This chain update is probably inefficient, since after the rows that follow are
updated, they will be updated again when it's their turn in `drawRows()` to be
updated. We could use a Buffer field to track how many lines could skip the
update, because they've been updated this way. We're not doing it, though.
```
