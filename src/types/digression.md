# Digression: default initializers

When defining the `Screen` type, I wrote that Zig supports default initializers
for structs, with a catch. The catch is that they may be the source of illegal
behaviors, as stated by the [official language
reference](https://ziglang.org/documentation/master/#toc-Faulty-Default-Field-Values).

In the example from that link, it's not too clear at first sight what's the
problem in that struct is, so it's worth pointing it out.

Given this struct:
```zig
const Threshold = struct {
    minimum: f32 = 0.25,
    maximum: f32 = 0.75,

    fn validate(t: Threshold, value: f32) void {
        assert(t.maximum >= t.minimum);
    }
};
```

If we create a variable like this:

    var a = Threshold{ .maximum = 0.2 };

we created a variable where the maximum is smaller than the minimum, and the
`validate()` function would panic at runtime. So if in your code you rely on
the assumption that `maximum` is always greater than `minimum`, you could fall
into some illegal behavior.

For this reason in this program I avoid default initializers for complex types
that have methods, which may
access those values. I only use them for simple types without methods, because
it's hard to give up the convenience of being able to write:

    var a = SomeType{};

For more complex types I use a `init()` function that returns the
instance, as it's customary to have such functions, and set default values
there.

### [undefined](https://ziglang.org/documentation/master/#undefined) as default value

`undefined` is generally used for local variables whose lifetime is limited and
obvious, as obvious is the place where they acquire a meaningful value. The
compiler will not warn you if you use variable set to `undefined`. Instead, it
will warn you if you don't initialize a member. Therefore you should have
a really good reason to set an `undefined` default value inside structs.

Anyway, why using `undefined` at all? For example, sometimes you need
a variable declared beforehand in an upper scope. In this case, setting it to
a value that it is meant to be overwritten would cause confusion: why am
I setting it to that value? The intent of `undefined` is clear instead: this
variable _must_ acquire a meaningful value later on.

[Sze from the Ziggit forum says:](https://ziggit.dev/t/port-of-kilo-editor-to-zig/11463/13)

You are telling the compiler that you **want** the value to be undefined.
And there aren’t enough safety checks yet so that all ways to use such an
undefined value would be caught reliably. So for now you have to be careful and
it is better to only use undefined, when you are making sure that you are
setting it to a valid value before you actually use it.
In cases where some field sometimes needs to be set to undefined, it is better
to avoid using a field default value for that and instead pass undefined for
that field value explicitly during initialization/setup.
