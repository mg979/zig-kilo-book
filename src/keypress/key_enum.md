# The Key enum

Let's start with the enum, it will be placed in the 'other types' section of
the `types` module:

<div class="code-title">types.zig</div>

```zig
/// ASCII codes of the keys, as they are read from stdin.
pub const Key = enum(u8) {
    ctrl_b = 2,
    ctrl_c = 3,
    ctrl_d = 4,
    ctrl_f = 6,
    ctrl_g = 7,
    ctrl_h = 8,
    tab = 9,
    ctrl_j = 10,
    ctrl_k = 11,
    ctrl_l = 12,
    enter = 13,
    ctrl_q = 17,
    ctrl_s = 19,
    ctrl_t = 20,
    ctrl_u = 21,
    ctrl_z = 26,
    esc = 27,
    backspace = 127,
    left = 128,
    right = 129,
    up = 130,
    down = 131,
    del = 132,
    home = 133,
    end = 134,
    page_up = 135,
    page_down = 136,
    _,
};
```

This is a [non-exhaustive
enum](https://ziglang.org/documentation/master/#Non-exhaustive-enum): it has an
underscore as last element.

Generally, enums are a strongly namespaced type. You can't infer an integer
from it, if that _enum_ doesn't have a _member_ with that value.
_Non-exhaustive_ enums are more permissive: they are like a set of all integers
of a certain type, some of which have been given a name.

This means that we will be able to cast an integer to an enum member (with
`@enumFromInt`), even if the _enum_ doesn't have a _member_ for that integer.

Why do we want this? Because we aren't going to give a name to all possible
keys:
- `readKey()` will read `u8` characters through `readChars()`
- `readKey()` will return a `Key`, so it must be able turn any `u8` character
into a `Key` enum member

But this character may be a letter, a digit, or anything that doesn't have
a field in that enum. We want to full interoperation with all possible `u8`
values.
