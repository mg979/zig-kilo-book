## Line comments

For line comments we just check we aren't in a string or in a multiline
comment, and we look for the comment leader. If found, the rest of the line is
a comment, no need to continue parsing this line.

<div class="code-title">Editor.zig: inside updateHighlight() top-level loop</div>

```zig
        // single-line comment
        if (lc.len > 0 and !in_string and !in_mlcomment) {
            for (lc) |ldr| {
                if (i + ldr.len <= rowlen and str.eql(row.render[i .. i + ldr.len], ldr)) {
                    @memset(row.hl[i..], t.Highlight.comment);
                    break :toplevel;
                }
            }
        }
```

## Strings

Highlighting of strings is controlled by `Syntax.flags.strings`, but that's not
enough. Syntaxes can support double quoted strings, single quoted strings,
backticks as strings or _char_ literals, or more often a combination of them.

`in_string` and `in_char` differ because the highlight is different (_string_
vs _number_). Moreover different delimiters must be handled independently: if
a double quote is found and a string starts, a single quote after that is still
part of the string. Same is true for double quotes after single quotes.

Whatever the delimiter and the string type, an escaped character is an escaped
character, and it gets the `.escape` highlight, together with the escaping
backslash.

If the start of a string or a _char_ literal is found, `delimiter` is set to
the character, and the appropriate highlight is set until `delimiter` is found
again.

Multi-line strings aren't supported.

<div class="code-title">Editor.zig: inside updateHighlight() top-level loop</div>

```zig
        if (flags.strings) {
            if (in_string or in_char) {
                if (escaped or row.render[i] == '\\') {
                    escaped = !escaped;
                    row.hl[i] = t.Highlight.escape;
                }
                else {
                    row.hl[i] = if (in_char) t.Highlight.number else t.Highlight.string;
                    if (row.render[i] == delimiter) {
                        in_string = false;
                        in_char = false;
                    }
                }
                i += 1;
                continue :toplevel;
            }
            else if (flags.dquotes and row.render[i] == '"'
                     or flags.squotes and row.render[i] == '\''
                     or flags.backticks and row.render[i] == '`') {
                in_string = true;
                delimiter = row.render[i];
                row.hl[i] = t.Highlight.string;
                i += 1;
                continue :toplevel;
            }
            else if (flags.chars and row.render[i] == '\'') {
                in_char = true;
                delimiter = row.render[i];
                row.hl[i] = t.Highlight.number;
                i += 1;
                continue :toplevel;
            }
        }
```
