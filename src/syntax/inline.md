# Digression: inline keyword

### `inline` with functions

```
The inline calling convention forces a function to be inlined at all call sites.
If the function cannot be inlined, it is a compile-time error.
```

This what the creator of the Zig language
[wrote](https://ziggit.dev/t/inlining-functions/1341/3):

```admonish quote
It’s best to let the compiler decide when to inline a function, except for
these scenarios:

-   You want to change how many stack frames are in the call stack, for
debugging purposes
-   You want the comptime-ness of the arguments to propagate to the return
value of the function
-   Performance measurements _demand_ it. Don’t guess!

Otherwise you actually end up _restricting_ what the compiler is allowed to do
when you use `inline` which can harm binary size, compilation speed, and even
runtime performance.
```

So basically he's recommending _not_ to use it unless you have a _good_ and
_measurable_ reason to do so.

### Other uses of inline

From the [official language reference](https://ziglang.org/documentation/0.15.1):

- [inline functions](https://ziglang.org/documentation/0.15.1/#inline-fn)
- [inline while](https://ziglang.org/documentation/0.15.1/#inline-while)
- [inline for](https://ziglang.org/documentation/0.15.1/#inline-for)
- [inline switch prongs](https://ziglang.org/documentation/0.15.1/#Inline-Switch-Prongs)

Other uses of `inline` are very different, because they usually allow loops to
be evaluated at compile time. I've never used them, since I never felt the need
for them, so I can't tell you more.
