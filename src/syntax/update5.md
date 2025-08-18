# Numbers

Parsing numbers depends on syntax flags: different filetypes support different
number formats. The formats we support are:

| type          | format          | flag      |
|---------------|-----------------|-----------|
| integers      | `N`             | numbers   |
| floats        | `N.N([eE]N)?`   | numbers   |
| hex           | `0[xX]N`        | hex       |
| octal         | `0[oO]N`        | octal     |
| binary        | `0[bB]N`        | bin       |

Integers and floats are always parsed if `flags.numbers` is true.

First we check if it's some special number notation (hex, octal binary). If
true, we set the appropriate boolean variable and advance the index by
2 characters.

<div class="code-title">Editor.zig: inside updateHighlight() top-level loop</div>

```zig
        // numbers
        if (flags.numbers and prev_sep) {
            var prev_digit = false;
            var is_float = false;
            var has_exp = false;
            var is_hex = false;
            var is_bin = false;
            var is_octal = false;
            var NaN = false;

            const begin = i;

            // hex, binary, octal notations
            if (i + 1 < rowlen) {
                if (row.render[i] == '0') {
                    switch (row.render[i + 1]) {
                        'x', 'X' => if (flags.hex) {
                            is_hex = true;
                            i += 2;
                        },
                        'b', 'B' => if (flags.bin) {
                            is_bin = true;
                            i += 2;
                        },
                        'o', 'O' => if (flags.octal) {
                            is_octal = true;
                            i += 2;
                        },
                        else => {},
                    }
                }
            }
```

Then we parse the actual number. What counts as a digit depends on the type
that has been detected. If it's not a special notation, we only accept digits
and a dot.

The variable `prev_digit` is true if the previous character was a valid digit
for the type. This variable must be true at the end of the parsing, or this
simply isn't a number.

If `flags.uscn` is true, we also accept underscores as separator. They are part
of the number, but they aren't digits themselves, so if they aren't followed by
a digit, it won't be a number.

For the dot, it's similar: it requires to be followed by a digit, otherwise
it's a simple separator. Not only that, but there can be only one dot in the
number. Finding a dot the first time sets `is_float`, finding it twice means
it's not a number.

Same goes for `e/E` (exponent): they must be followed by digits, and may not
appear more than once. If it's a hex digit, though, `e/E` are digits, not
exponents.

<div class="code-title">Editor.zig: flags.numbers</div>

```zig
            // accept consecutive digits, or a dot followed by a number
            digits: while (true) : (i += 1) {
                if (i == rowlen) break :digits;

                switch (row.render[i]) {
                    '0'...'1' => prev_digit = true,

                    // invalid for binary numbers
                    '2'...'7' => {
                        if (!is_bin) {
                            prev_digit = true;
                        }
                        else {
                            prev_digit = false;
                            break :digits;
                        }
                    },

                    // invalid for binary and octal numbers
                    '8'...'9' => {
                        if (!is_bin and !is_octal) {
                            prev_digit = true;
                        }
                        else {
                            prev_digit = false;
                            break :digits;
                        }
                    },

                    // underscores as delimiters in numeric literals
                    '_' => {
                        if (prev_digit and flags.uscn) {
                            prev_digit = false;
                        }
                        else {
                            break :digits;
                        }
                    },

                    // could be an exponent, or a hex digit
                    'e', 'E' => {
                        if (is_float and !has_exp) {
                            has_exp = true;
                            prev_digit = false;
                        }
                        else if (is_hex) {
                            prev_digit = true;
                        }
                        else {
                            break :digits;
                        }
                    },

                    // hex digits
                    'a'...'d', 'f', 'A'...'D', 'F' => {
                        if (is_hex) prev_digit = true else break :digits;
                    },

                    // floating point
                    '.' => {
                        prev_sep = true;
                        prev_digit = false;
                        if (!is_float and !is_hex and !is_bin) {
                            is_float = true;
                        }
                        else {
                            break :digits;
                        }
                    },

                    else => break :digits,
                }
            }
```

After the loop ends, because a character has been found that is not valid for
the type of number, we check if it's actually a number:

- last character must be a valid digit
- it must be followed by either a separator or end of line

We must also set the very important `prev_sep` variable, which controls whether
the following characters may be parsed as new tokens, or as part of the
previous one, or not at all. In this case, since we only have keywords left to
parse, if this is `false` it will effectively end the parsing of the line.

If end of line has been reached we stop.

<div class="code-title">Editor.zig: flags.numbers</div>

```zig
            // previous separator could be invalid if any character was
            // processed
            prev_sep = i == begin or str.isSeparator(row.render[i - 1]);

            // no matter the type of number, last character should be a digit
            if (!prev_digit) {
                NaN = true;
            }
            // after our number comes something that isn't a separator
            else if (i != rowlen and !str.isSeparator(row.render[i])) {
                NaN = true;
            }
            if (!NaN) {
                for (begin..i) |idx| {
                    row.hl[idx] = t.Highlight.number;
                }
            }
        }
        if (i == rowlen) break :toplevel;
```
