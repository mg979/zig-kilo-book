# Write a test

Let's write a test to see if what we wrote is working.

### Run tests from main.zig

To run this test with

    zig build test

we must add a section to our `main.zig` module:

<div class="code-title">main.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Tests
//
///////////////////////////////////////////////////////////////////////////////

comptime {
    if (builtin.is_test) {
        _ = @import("Editor.zig");
    }
}
```

In fact, our `build.zig` is set up in a way that running `zig build test`
executes the tests that are in `main.zig`. When tests are executed from
a module, all tests placed in imported modules are executed too.

We don't want any test in `main.zig`, but with this `comptime` block we import
the modules we want to test, if `builtin.is_test` is true, and this happens
only when we're running tests.

Importing these modules will cause their tests to be executed, which is what we
want.

### Add the test in Editor

You should add some constants in `Editor`:

<div class="code-title">Editor.zig</div>

```zig
const linux = @import("linux.zig");

const mem = std.mem;
const expect = std.testing.expect;
```

Then we add a test to `src/Editor.zig`. Add the test section just above the
Constants section.

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Tests
//
///////////////////////////////////////////////////////////////////////////////

test "insert rows" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    var e = try t.Editor.init(da.allocator(), .{ .rows = 50, .cols = 180 });
    try e.openFile("src/main.zig");
    defer e.deinit();

    const row = e.rowAt(6).chars.items;
    try expect(mem.eql(u8, "pub fn main() !void {", row));
}
```

It's a simple test that verifies the number of rows that have been read, and
that the content of one row actually matches the one in the file.

I initialize the editor with a 'fake' screen, because this isn't an interactive
terminal. Also, we avoid the event loop by reading directly the file with
`openFile()`, otherwise `processKeypress()` would hang the test.

If we modify `main.zig` again, this test could fail, or course. I will not, but
maybe you will.
