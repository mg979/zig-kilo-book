# Digression: assignments in Zig

In Zig, it's really important that you pay attention to details, which, if you
have mainly experience with OOP languages, you may find confusing or even
frustrating. It has to do with the fact that in Zig, as in C, all assignments
imply a copy _by value_.

This is especially important when assigning `struct` values. Most OOP
languages, when assigning _objects_, take a _reference_ to it. But in Zig
structs are not references, they are _values_, and they are _copied_ when
assigned.

### The case of the Io.Reader interface

The interface is a nested struct in the reader. To work, it uses a builtin
function called `@fieldParentPtr()` that desumes the address of its parent, so
that the interface knows the address of the struct that contains it. But if
instead of writing:

    var reader = file.reader(&buf);
    while (reader.interface.takeDelimiterExclusive('\n')) |line|

you write:

    var reader = file.reader(&buf).interface;
    while (reader.takeDelimiterExclusive('\n')) |line|

then you make a _copy_ of that interface, which is orphan, can't take a valid
address of its parent because it doesn't have one, and is essentially broken.

There's also the problem that `file.reader(&buf)`, which is the legitimate
parent, in the second form doesn't have a stable address, because it's not
assigned to any variable, meaning that in the second expression it's temporary
memory that becomes immediately invalid at the end of the assignment. So even
if `interface` wasn't a copy and could still get its address, it would be
invalid memory anyway.

The program will panic at runtime (in safe builds!), and the error reported can
be hard to understand. Unfortunately Zig documentation is still immature, so
right now you'll have to find out the hard way how these things work.

These kind of issues can be frustrating if you're used to OOP languages, which
are generally designed to perform complex operations under the hood, hiding the
details of the implementation from the user, for the sake of easiness of use.

In OOP languages when you _assign_ something, often you aren't copying by
_value_, but you are taking a _reference_ to an object. In Zig you are expected
to understand what assignments do (they always copy by _value_), and what you
are really assigning.

Other example, many OOP languages have _private_ fields, which can't be
accessed outside of a certain scope. Zig has nothing like that, and everything
is in plain sight, but it expects that you know what you're doing. As the
creator of Zig [said](https://ziggit.dev/t/0-15-1-reader-writer/11614/26):

    it all comes down to simplicity. Other languages hide complex details from
    you; Zig keeps things simpler but in exchange requires you to understand
    those details.

That said, there's probably room for improvement, and possibly there will be
ways, in the future, to at least prevent accidental mistakes.

#### Interesting discussions and posts

- [discussion](https://ziggit.dev/t/zig-0-15-1-reader-writer-dont-make-copies-of-fieldparentptr-based-interfaces/11719)
- [post](https://ziggit.dev/t/zig-0-15-1-reader-writer-dont-make-copies-of-fieldparentptr-based-interfaces/11719/7)
