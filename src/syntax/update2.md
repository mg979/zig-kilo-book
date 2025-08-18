# Top-level symbols

Before we start the loop that iterates all characters visible on screen, we
define some constants and variables.

The most important one is `prev_sep`: it controls when we can start to parse
something new. If this variable isn't set correctly where it needs to be,
highlighting of will be likely broken.

`in_string`, which tells us if we're in a string or not, is checked early since
inside strings we should ignore everything else, except escaped characters (for
which we have an `escaped` variable).

Similarly for `in_mlcomment`: also in this case we don't parse anything until
we find the sequence that closes the comment.

```zig
    //////////////////////////////////////////
    //          Top-level symbols
    //////////////////////////////////////////

    // length of the rendered row
    const rowlen = row.render.len;

    // syntax definition
    const s = e.buffer.syndef.?;

    // line comment leader
    const lc = s.lcmt;

    // multiline comment leaders
    const mlc = s.mlcmt;

    // syntax flags
    const flags = s.flags;

    // character is preceded by a separator
    var prev_sep = true;

    // character is preceded by a backslash
    var escaped = false;

    // character is inside a string or char literal
    var in_string = false;
    var in_char = false;
    var delimiter: u8 = 0;

    // line is in a multiline comment
    var in_mlcomment = ix > 0 and e.buffer.rows.items[ix - 1].ml_comment;

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

## The top-level loop

We'll have multiple nested loops, so we will use labels to break to an outer
loop. The top-level loop has the `toplevel` label.

We'll use labels for all loops, and all `break` and `continue` statements. This
way it should be clearer from which loop we're breaking.

At the bottom of the top-level loop we'll increase the row index and set the
_critical_ `prev_sep` variable.

First thing we do is to skip whitespaces, which are also a valid separator.

```zig
    var i: usize = 0;
    toplevel: while (i < rowlen) {
        if (asc.isWhitespace(row.render[i])) { // skip whitespaces
            prev_sep = true;
            i += 1;
            continue :toplevel;
        }

        // rest of parsing goes here...

        prev_sep = str.isSeparator(row.render[i]);
        i += 1;
    }
```
