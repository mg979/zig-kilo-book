# Doing the search

Our prompt accepts a callback now, so we're ready to implement the search
functionality.

We bind a new key:

<div class="code-title">Editor.zig: processKeypress()</div>

```zig
        .ctrl_f => try e.find(),
```

Then we define our function:

<div class="code-title">Editor.zig</div>

```zig
///////////////////////////////////////////////////////////////////////////////
//
//                              Find
//
///////////////////////////////////////////////////////////////////////////////

/// Start the search prompt.
fn find(e: *Editor) !void {
    const saved = e.view;
    var query = try e.promptForInput("/", saved, findCallback);
    query.deinit(e.alc);
}
```

In this function, we make a copy of the current View, so that we can restore
the cursor position in the case that the search is interrupted.

We get our query, then deinitialize it. It's clear we're missing some piece of
the puzzle...

Which brings us to the `findCallback()` function, which is passed to the
prompt.
