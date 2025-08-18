# The screen surface

Now we're finally ready to start drawing on the screen.

We'll use an ArrayList to hold all characters that will be printed on every
screen refresh.

We'll add a new field to our Editor type:

<div class="code-title">Editor.zig</div>

```zig
/// String that is printed on the terminal at every screen redraw
surface: t.Chars,
```

It is initialized in the `init()` function:

<div class="code-title">Editor.zig: init()</div>

<div class="code-diff-removed">

```zig
    return .{
        .alc = allocator,
```
</div>

```zig
    // multiply * 10, because each cell could contain escape sequences
    const surface_capacity = screen.rows * screen.cols * 10;
    return .{
        .alc = allocator,
        .surface = try t.Chars.initCapacity(allocator, surface_capacity),
```

We give our `surface` an initial capacity, so that it will probably never
reallocate. We make enough room for escape sequences: potentially, almost every
cell of the screen could contain an escape sequence.

`surface` must be deinitialized in `deinit()`, or it will leak:

<div class="code-title">Editor.zig: deinit()</div>

<div class="code-diff-added">

```zig
/// Deinitialize the editor.
pub fn deinit(e: *Editor) void {
    e.buffer.deinit();
```
</div>

```zig
    e.surface.deinit(e.alc);
```

Note that we must pass the allocator as argument when deinitializing an
ArrayList.

### Appending to the surface

Every time we want to append to the surface, we'd need either:

<pre class="code-block-small"><code class="language-zig">try e.surface.appendSlice(e.alc, slice);
</code></pre>

or

<pre class="code-block-small"><code class="language-zig">try e.surface.append(e.alc, character);
</code></pre>

Let's create a helper function, because we'll append to the surface in lots
of places, and we want our code to be more concise and readable.

<div class="code-title">Editor.zig</div>

```zig
/// Append either a slice or a character to the editor surface.
fn toSurface(e: *Editor, value: anytype) !void {
    switch (@typeInfo(@TypeOf(value))) {
        .pointer => try e.surface.appendSlice(e.alc, value),
        else => try e.surface.append(e.alc, value),
    }
}
```

With this function we just need to do:

<pre class="code-block-small"><code class="language-zig">try e.toSurface(slice_or_character);
</code></pre>

```admonish note title="@TypeOf"
Builtin function `@TypeOf()` returns a type, which can only be evaluated at
compile time, hence our helper doesn't have any runtime cost, because the
operation to perform is decided at compile time. As proof of this, you will get
a compile error if you pass something wrong to this function.
```
