## Keywords

Remember the constant we set before the top-level loop started:

```zig
    // all keywords in the syntax definition, subdivided by kinds
    // each kind has its own specific highlight
    const all_syn_keywords = [_]struct {
        kind: []const []const u8, // array with keywords of some kind
        hl: t.Highlight,
    }{
        .{ .kind = s.keywords, .hl = t.Highlight.keyword },
        .{ .kind = s.types,    .hl = t.Highlight.types },
        .{ .kind = s.builtin,  .hl = t.Highlight.builtin },
        .{ .kind = s.constant, .hl = t.Highlight.constant },
        .{ .kind = s.preproc,  .hl = t.Highlight.preproc },
    };
```

Now we iterate this array. Each element of this array is a set of keywords
(`[]const []const u8`), together with the highlight which they will use.

We loop each of these sets of keyword: if we find that what follows the current
position is the keyword, we set the highlight and advance the position by the
keyword length.

<div class="code-title">Editor.zig: inside updateHighlight() top-level loop</div>

```zig
        // keywords
        if (prev_sep) {
            kwloop: for (all_syn_keywords) |keywords| {
                for (keywords.kind) |kw| {
                    const kwend = i + kw.len; // index where keyword would end

                    // separator or end of row after keyword
                    if ((kwend < rowlen and str.isSeparator(row.render[kwend]))
                        or kwend == rowlen)
                    {
                        if (str.eql(row.render[i..kwend], kw)) {
                            @memset(row.hl[i..kwend], keywords.hl);
                            i += kw.len;
                            break :kwloop;
                        }
                    }
                }
            }
```

## Uppercase words

Similar process, but we don't loop any array, we just check if there's
a sequence of uppercase characters or underscores.

```admonish important
We must reset the `prev_sep` variable before continuing, or the loop will hang.
```

<div class="code-title">Editor.zig: inside updateHighlight() continuing block</div>

```zig
            if (flags.uppercase) {
                var upper = false;
                const begin = i;
                upp: while (i < rowlen and !str.isSeparator(row.render[i])) {
                    if (!asc.isUpper(row.render[i]) and row.render[i] != '_') {
                        upper = false;
                        break :upp;
                    }
                    upper = true;
                    i += 1;
                }
                if (upper and i - begin > 1) {
                    @memset(row.hl[begin..i], t.Highlight.uppercase);
                }
            }
            prev_sep = false;
            continue :toplevel;
        }
```
