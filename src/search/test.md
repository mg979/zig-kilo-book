# Write a test

By now you should be able to compile, run and test the feature yourself.

Anyway, the searching feature is way more complex than anything we did before,
and it's worth writing a test for it.

I don't know how to simulate keystrokes, so I'm just calling the callback
repeatedly.

I initialize the editor with a 'fake' screen, because this isn't an interactive
terminal.

Remember that we can do array multiplications (`**`) and concatenation (`++`),
but only in comptime scopes.

I won't explain what the test does, hopefully you'll be able to understand it.

<div class="code-title">Editor.zig: Tests section</div>

```zig
test "find" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    var e = try t.Editor.init(da.allocator(), .{ .rows = 50, .cols = 180 });
    defer e.deinit();

    opt.wrapscan = true;
    opt.tabstop = 8;

    // our test buffer
    try e.insertRow(e.buffer.rows.items.len, "\tabb");
    try e.insertRow(e.buffer.rows.items.len, "\tacc");
    try e.insertRow(e.buffer.rows.items.len, "\tadd\tadd");

    const n = [1]t.Highlight{ .normal };
    const s = [1]t.Highlight{ .incsearch };

    // Row.hl has the same number of elements as the rendered row, and here we
    // have tabs

    // first 2 lines: normal highlight
    const norm1 = n ** 11;
    // third line: normal highlight
    const norm2 = n ** 19;
    // \t + 1 letter in lines 1-2
    const hl = s ** 9 ++ n ** 2;
    // \t + 2 letters in lines 1-2
    const hl2 = s ** 10 ++ n ** 1;
    // \t + 2 letters in line 3, first match
    const hl3 = s ** 10 ++ n ** 9;
    // \t + 1 letter in line 3, first match
    const hl4 = s ** 9 ++ n ** 10;
    // \t + 1 letter in line 3, second match
    const hl5 = n ** 11 ++ s ** 6 ++ n ** 2;

    var al = try t.Chars.initCapacity(e.alc, 80);
    defer al.deinit(e.alc);

    // our prompt is "\ta", it should be found in line 2, because we skip the
    // match at cursor position
    try al.appendSlice(e.alc, "\ta");
    var ca: t.PromptCbArgs = .{ .input = &al, .key = @enumFromInt('a'), .saved = e.view };
    try e.findCallback(ca);

    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &hl));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &norm2));

    // now it's "\tac", extending the current match
    try al.append(e.alc, 'c');
    ca = .{ .input = &al, .key = @enumFromInt('c'), .saved = e.view };
    try e.findCallback(ca);

    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &hl2));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &norm2));

    // now it's "\ta", resizing the current match
    _ = al.pop();
    ca = .{ .input = &al, .key = .backspace, .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &hl));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &norm2));

    // now it's "\tad", found in line 3
    try al.append(e.alc, 'd');
    ca = .{ .input = &al, .key = @enumFromInt('d'), .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &hl3));

    // now it's "\ta", resizes the current match
    _ = al.pop();
    ca = .{ .input = &al, .key = .backspace, .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &hl4));

    // find next: finds another "\ta" in the same row
    ca = .{ .input = &al, .key = .ctrl_g, .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &hl5));

    // find next again: finds "\ta" in the first line
    ca = .{ .input = &al, .key = .ctrl_g, .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &hl));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &norm2));

    // find prev: goes back to last line (2nd match)
    ca = .{ .input = &al, .key = .ctrl_t, .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &hl5));

    opt.wrapscan = false;

    // find next should fail (stays the same)
    ca = .{ .input = &al, .key = .ctrl_g, .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &hl5));

    // not found
    try al.append(e.alc, 'z');
    ca = .{ .input = &al, .key = @enumFromInt('z'), .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &norm2));

    // not found: stays the same
    ca = .{ .input = &al, .key = .ctrl_g, .saved = e.view };
    try e.findCallback(ca);
    try expect(mem.eql(t.Highlight, e.rowAt(0).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(1).hl, &norm1));
    try expect(mem.eql(t.Highlight, e.rowAt(2).hl, &norm2));

    // clean up
    ca.final = true;
    try e.findCallback(ca);
}
```
