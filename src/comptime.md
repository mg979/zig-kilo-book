# Digression: the comptime keyword

You probably know of `comptime` in Zig. Here we have an application of the
concept: since the `builtin.is_test` variable is evaluated at compile time, the
whole branch in `getWindowSize()` can be resolved at compile time, the relative
code will be removed and will not be executed at runtime.

This has the same effect of an `#ifdef` block in C for conditional compilation,
but the syntax looks much less intrusive. You can even force any expression to
be evaluated at compile time by using the `comptime` keyword before the
expression, but here it's not needed, because the `builtin.is_test` variable is
guaranteed to be compile-time known.

While using the `comptime` keyword, sometimes the compiler complains that using
the keyword is redundant, because the expression is always compile-time known,
other times it doesn't complain, as in the case above, even if I'm pretty sure
that all `builtin` variables are compile-time known. We saw another example in
the `main()` function, where the allocator was chosen by testing the
`builtin.mode` variable.

To my understanding, also from reading several posts made by the original
creator of Zig (Andrew Kelley), most of the time it's not necessary to use the
keyword, the compiler is smart enough to evaluate at compile time what it can,
even if you don't specify it expressly. But sometimes the compiler says:

    error: unable to resolve comptime value

In these cases the `comptime` keyword might fix the issue.

Bottom line: don't be compulsive in filling your code with `comptime`, it's not
necessary.
