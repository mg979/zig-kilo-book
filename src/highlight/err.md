# More comptime

We used a hard-coded `ErrorColor` when printing errors in the message area,
time to change it in `errorMessage()`:

<div class="code-diff-removed">

```zig
    const fmt = ansi.ErrorColor ++ format ++ ansi.ResetColors;
```
</div>

```zig
    const fmt = comptime t.HlGroup.attr(.err) ++ format ++ ansi.ResetColors;
```

You should now delete the `ErrorColor` constant from `ansi`.

Note the `comptime` keyword here. Without it, the compiler would say:

    error: unable to resolve comptime value
    note: slice being concatenated must be comptime-known

With the `comptime` keyword, you force the compiler to at least _try_ to get
that value at compile time. In this case, it succeeds. Also note that
`comptime` can precede any expression, to force it being evaluated at compile
time: function calls, assignments, etc.

**Again**: you generally don't need the `compile` keyword. But if the compiler
complains with that sort of errors, and you think it should be able to get the
value, it's worth a try.

