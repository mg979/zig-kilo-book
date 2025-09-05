//! Type that manages most of the editor functionalities.
//! It draws the main window, the statusline and the message area, and controls
//! the event loop.

/// Allocator used by the editor instance
alc: mem.Allocator,

/// The size of the terminal window where the editor runs
screen: t.Screen,

/// Text buffer the user is currently editing
buffer: t.Buffer,

/// Tracks cursor position and part of the buffer that fits the screen
view: t.View,

/// Becomes true when the main loop should stop, causing the editor to quit
should_quit: bool,

/// String that is printed on the terminal at every screen redraw
surface: t.Chars,

/// String to be printed in the message area (can be a prompt)
status_msg: t.Chars,

/// Controls the visibility of the status message
status_msg_time: i64,

/// String to be displayed when the editor is started without loading a file
welcome_msg: t.Chars,

/// Becomes false after the first screen redraw
just_started: bool,

///////////////////////////////////////////////////////////////////////////////
//
//                              Init/deinit
//
///////////////////////////////////////////////////////////////////////////////

/// Return the initialized editor instance.
pub fn init(allocator: mem.Allocator, screen: t.Screen) !Editor {
    // multiply * 10, because each cell could contain escape sequences
    const surface_capacity = screen.rows * screen.cols * 10;
    return .{
        .alc = allocator,
        .surface = try t.Chars.initCapacity(allocator, surface_capacity),
        .screen = .{
            .rows = screen.rows - 2, // make room for statusline/message area
            .cols = screen.cols,
        },
        .buffer = try t.Buffer.init(allocator),
        .view = .{},
        .should_quit = false,
        .status_msg = try t.Chars.initCapacity(allocator, initial_msg_size),
        .status_msg_time = 0,
        .welcome_msg = try t.Chars.initCapacity(allocator, 0),
        .just_started = true,
    };
}

/// Deinitialize the editor.
pub fn deinit(e: *Editor) void {
    e.buffer.deinit();
    e.surface.deinit(e.alc);
    e.status_msg.deinit(e.alc);
    e.welcome_msg.deinit(e.alc);
}

/// Start up the editor: open the path in args if valid, start the event loop.
pub fn startUp(e: *Editor, path: ?[]const u8) !void {
    try e.statusMessage(message.status.get("help").?, .{});
    if (path) |name| {
        try e.openFile(name);
    }
    else {
        try e.generateWelcome();
    }

    while (e.should_quit == false) {
        try e.refreshScreen();
        try e.processKeypress();
    }
}

/// Read all lines from file.
fn readLines(e: *Editor, file: std.fs.File) !void {
    var buf: [1024]u8 = undefined;
    var reader = file.reader(&buf);

    var line_writer = std.Io.Writer.Allocating.init(e.alc);
    defer line_writer.deinit();

    while (reader.interface.streamDelimiter(&line_writer.writer, '\n')) |_| {
        try e.insertRow(e.buffer.rows.items.len, line_writer.written());
        line_writer.clearRetainingCapacity();
        reader.interface.toss(1); // skip the newline
    }
    else |err| if (err != error.EndOfStream) return err;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              File operations
//
///////////////////////////////////////////////////////////////////////////////

/// Open a file with `path`.
fn openFile(e: *Editor, path: []const u8) !void {
    var B = &e.buffer;

    // store the filename into the buffer
    B.filename = try e.updateString(B.filename, path);

    // read lines if the file could be opened
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only });
    if (file) |f| {
        defer f.close();
        try e.readLines(f);
    }
    else |err| switch (err) {
        error.FileNotFound => {}, // new unsaved file
        else => return err,
    }

    B.dirty = false;
}

/// Try to save the current file, prompt for a file name if currently not set.
/// Currently saving the file fails if directory doesn't exist, and there is no
/// tilde expansion.
fn saveFile(e: *Editor) !void {
    var B = &e.buffer;

    if (B.filename == null) {
        var al = try e.promptForInput(message.prompt.get("fname").?);
        defer al.deinit(e.alc);

        if (al.items.len > 0) {
            B.filename = try e.updateString(B.filename, al.items);
        }
        else {
            try e.statusMessage("Save aborted", .{});
            return;
        }
    }

    // determine number of bytes to write, make room for \n characters
    var fsize: usize = B.rows.items.len;
    for (B.rows.items) |row| {
        fsize += row.chars.items.len;
    }

    const file = std.fs.cwd().createFile(B.filename.?, .{ .truncate = true });
    if (file) |f| {
        var buf: [1024]u8 = undefined;
        var writer = f.writer(&buf);
        defer f.close();
        // for each line, write the bytes, then the \n character
        for (B.rows.items) |row| {
            writer.interface.writeAll(row.chars.items) catch |err| return e.ioerr(err);
            writer.interface.writeByte('\n') catch |err| return e.ioerr(err);
        }
        // write what's left in the buffer
        try writer.interface.flush();
        try e.statusMessage(message.status.get("bufwrite").?, .{
            B.filename.?, B.rows.items.len, fsize
        });
        B.dirty = false;
        return;
    }
    else |err|{
        e.alc.free(B.filename.?);
        B.filename = null;
        return e.ioerr(err);
    }
}

/// Handle an error of type IoError by printing an error message, without
/// quitting the editor.
fn ioerr(e: *Editor, err: t.IoError) !void {
    try e.errorMessage(message.errors.get("ioerr").?, .{@errorName(err)});
    return;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Row operations
//
///////////////////////////////////////////////////////////////////////////////

/// Insert a row at index `ix` with content `line`, then update it.
fn insertRow(e: *Editor, ix: usize, line: []const u8) !void {
    const B = &e.buffer;

    var row = try t.Row.init(B.alc);
    try row.chars.appendSlice(B.alc, line);

    try B.rows.insert(B.alc, ix, row);

    try e.updateRow(ix);
    B.dirty = true;
}

/// Delete a row and deinitialize it.
fn deleteRow(e: *Editor, ix: usize) void {
    var row = e.buffer.rows.orderedRemove(ix);
    row.deinit(e.buffer.alc);
    e.buffer.dirty = true;
}

/// Update row.render, that is the visual representation of the row.
/// Performs a syntax update at the end.
fn updateRow(e: *Editor, ix: usize) !void {
    const row = e.rowAt(ix);

    // get the length of the rendered row and reallocate
    const rlen = row.cxToRx(row.chars.items.len);
    row.render = try e.alc.realloc(row.render, rlen);

    var idx: usize = 0;
    var i: usize = 0;

    while (i < row.chars.items.len) : (i += 1) {
        if (row.chars.items[i] == '\t') {
            row.render[idx] = ' ';
            idx += 1;
            while (idx % opt.tabstop != 0) : (idx += 1) {
                row.render[idx] = ' ';
            }
        }
        else {
            row.render[idx] = row.chars.items[i];
            idx += 1;
        }
    }
    try e.updateHighlight(ix);
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Keys processing
//
///////////////////////////////////////////////////////////////////////////////

/// Process a keypress: will wait indefinitely for readKey, which loops until
/// a key is actually pressed.
fn processKeypress(e: *Editor) !void {
    const k = try ansi.readKey();

    const static = struct {
        var q: u8 = opt.quit_times;
        var verbatim: bool = false;
    };

    if (static.verbatim) {
        static.verbatim = false;
        switch (k) {
            // these cause trouble, don't insert them
            .enter,
            .ctrl_h,
            .backspace,
            .ctrl_j,
            .ctrl_k,
            .ctrl_l,
            .ctrl_u,
            .ctrl_z,
            => {
                try e.errorMessage(message.errors.get("nonprint").?, .{ k });
                return;
            },
            else => try e.insertChar(@intFromEnum(k)),
        }
        return;
    }
    const B = &e.buffer;
    const V = &e.view;

    switch (k) {
        .ctrl_k => static.verbatim = true,

        .ctrl_q => {
            if (B.dirty and static.q > 0) {
                try e.statusMessage(message.status.get("unsaved").?, .{static.q});
                static.q -= 1;
                return;
            }
            try ansi.clearScreen();
            e.should_quit = true;
        },

        .ctrl_s => try e.saveFile(),

        .ctrl_d, .ctrl_u, .page_up, .page_down => {
            // by how many rows we'll jump
            const leap = e.screen.rows - 1;

            // place the cursor at the top of the window, then jump
            if (k == .ctrl_u or k == .page_up) {
                V.cy = V.rowoff;
                V.cy -= @min(V.cy, leap);
            }
            // place the cursor at the bottom of the window, then jump
            else {
                V.cy = V.rowoff + e.screen.rows - 1;
                V.cy = @min(V.cy + leap, B.rows.items.len);
            }
            e.doCwant(.restore);
        },

        .backspace, .ctrl_h, .del => {
            if (k == .del) {
                e.moveCursorWithKey(.right);
            }
            try e.deleteChar();
            e.doCwant(.set);
        },

        .enter => try e.insertNewLine(),

        .home => {
            V.cx = 0;
            e.doCwant(.set);
        },

        .end => {
            // last row doesn't have characters!
            if (V.cy < B.rows.items.len) {
                V.cx = B.rows.items[V.cy].clen();
            }
            e.doCwant(.maxcol);
        },

        .left, .right => {
            e.moveCursorWithKey(k);
            e.doCwant(.set);
        },

        .up, .down => {
            e.moveCursorWithKey(k);
            e.doCwant(.restore);
        },

        else => {
            const c = @intFromEnum(k);
            if (k == .tab or asc.isPrint(c)) {
                try e.insertChar(c);
                e.doCwant(.set);
            }
        },
    }

    // reset quit counter for any keypress that isn't Ctrl-Q
    static.q = opt.quit_times;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              In-row operations
//
///////////////////////////////////////////////////////////////////////////////

/// Insert a character at current cursor position. Handle textwidth.
fn insertChar(e: *Editor, c: u8) !void {
    const V = &e.view;

    // last row, insert a new row before inserting the character
    if (V.cy == e.buffer.rows.items.len) {
        try e.insertRow(e.buffer.rows.items.len, "");
    }

    // insert the character and move the cursor forward
    try e.rowInsertChar(V.cy, V.cx, c);
    V.cx += 1;

    //////////////////////////////////////////
    //              textwidth
    //////////////////////////////////////////

    const row = e.currentRow();
    const rx = row.cxToRx(V.cx);

    if (opt.textwidth.enabled and rx > opt.textwidth.len and str.isWord(c)) {
        // will be 1 if a space before the wrapped word must be removed
        var skipw: usize = 0;

        // find the start of the current word
        var start: usize = rx - 1;

        while (start > 0) {
            if (!str.isWord(row.render[start - 1])) {
                // we want to remove a space before the wrapped word, but not
                // other kinds of separators (not even a tab, just in case)
                if (row.render[start - 1] == ' ') {
                    skipw = 1;
                }
                break;
            }
            start -= 1;
        }

        // only wrap if the word doesn't start at the beginning
        if (start > 0) {
            const wlen = rx - start;

            // move the cursor to the start of the word, also skipping a space
            V.cx = row.rxToCx(start - skipw);

            // new line insertion will carry over the word and delete the space
            try e.insertNewLine();

            // move forward the cursor to the end of the word
            V.cx += wlen;
        }
    }
}

/// Delete a character before cursor position (backspace).
fn deleteChar(e: *Editor) !void {
    const V = &e.view;
    const B = &e.buffer;

    // past the end of the file
    if (V.cy == B.rows.items.len) {
        e.moveCursorWithKey(.left);
    }

    // start of file
    if (V.cx == 0 and V.cy == 0) {
        return;
    }

    // delete character in current line
    if (V.cx > 0) {
        try e.rowDelChar(V.cy, V.cx - 1);
        V.cx -= 1;
    }
    // join with previous line
    else {
        V.cx = B.rows.items[V.cy - 1].clen();
        try e.rowInsertString(V.cy - 1, V.cx, e.currentRow().chars.items);
        e.deleteRow(V.cy);
        V.cy -= 1;
    }
}

/// Insert character `c` in the row with index `ix`, at column `at`.
fn rowInsertChar(e: *Editor, ix: usize, at: usize, c: u8) !void {
    try e.rowAt(ix).chars.insert(e.buffer.alc, at, c);
    try e.updateRow(ix);
    e.buffer.dirty = true;
}

/// Insert a string at position `at`, in the row at index `ix`.
fn rowInsertString(e: *Editor, ix: usize, at: usize, chars: []const u8) !void {
    try e.rowAt(ix).chars.insertSlice(e.buffer.alc, at, chars);
    try e.updateRow(ix);
    e.buffer.dirty = true;
}

/// Delete a character in the row with index `ix`, at column `at`.
fn rowDelChar(e: *Editor, ix: usize, at: usize) !void {
    _ = e.rowAt(ix).chars.orderedRemove(at);
    try e.updateRow(ix);
    e.buffer.dirty = true;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Insert lines
//
///////////////////////////////////////////////////////////////////////////////

/// Insert a new line at cursor position. Will carry to the next line
/// everything that is after the cursor.
fn insertNewLine(e: *Editor) !void {
    const V = &e.view;

    // make sure the beginning of the line is visible
    V.coloff = 0;

    // at first column, just insert an empty line above the cursor
    if (V.cx == 0) {
        try e.insertRow(V.cy, "");
        V.cy += 1;
        return;
    }

    // leading whitespace removed from characters after cursor
    var skipw: usize = 0;

    // extra characters for indent
    var ind: usize = 0;

    var oldrow = e.currentRow().chars.items;

    // any whitespace before the text that is going into the new row
    if (V.cx < oldrow.len) {
        skipw = str.leadingWhitespaces(oldrow[V.cx..]);
    }

    if (opt.autoindent) {
        ind = str.leadingWhitespaces(oldrow);

        // reduce indent if current column is within it
        if (V.cx < ind) {
            ind = V.cx;
        }
    }

    // will insert a row with the characters to the right of the cursor
    // skipping whitespace after the cursor
    try e.insertRow(V.cy + 1, oldrow[V.cx + skipw ..]);

    // proceed to the new row
    V.cy += 1;

    if (ind > 0) {
        // reassign pointer, invalidated by row insertion
        oldrow = e.rowAt(V.cy - 1).chars.items;

        // in new row, shift the old content forward, to make room for indent
        const newrow = try e.currentRow().chars.addManyAt(e.alc, 0, ind);

        // Copy the indent from the previous row.
        for (0..ind) |i| {
            newrow[i] = oldrow[i];
        }
    }

    // delete from the row above the content that we moved to the next row
    e.rowAt(V.cy - 1).chars.shrinkAndFree(e.alc, V.cx);

    // row operations have been concluded, update rows
    try e.updateRow(V.cy - 1);
    try e.updateRow(V.cy);

    // set cursor position at the start of the new line
    V.cx = ind;
    V.cwant = ind;
}

///////////////////////////////////////////////////////////////////////////////
//
//                              View operations
//
///////////////////////////////////////////////////////////////////////////////

/// Update the cursor position after a key has been pressed.
fn moveCursorWithKey(e: *Editor, key: t.Key) void {
    const V = &e.view;
    const numrows = e.buffer.rows.items.len;

    switch (key) {
        .left => {
            if (V.cx != 0) { // not the first column
                V.cx -= 1;
            }
            else if (V.cy > 0) { // move back to the previous row
                V.cy -= 1;
                V.cx = e.currentRow().clen();
            }
        },
        .right => {
            if (V.cy < numrows) {
                if (V.cx < e.currentRow().clen()) { // not the last column
                    V.cx += 1;
                }
                else { // move to the next row
                    V.cy += 1;
                    V.cx = 0;
                }
            }
        },
        .up => {
            if (V.cy != 0) {
                V.cy -= 1;
            }
        },
        .down => {
            if (V.cy < numrows) {
                V.cy += 1;
            }
        },
        else => {},
    }
}

/// Handle wanted column. `want` can be:
/// .set: set e.view.cwant to a new value
/// .maxcol: set to maxUsize, which means 'always the last column'
/// .restore: set current column to cwant, or to the last column if too big
fn doCwant(e: *Editor, want: t.Cwant) void {
    const V = &e.view;
    const numrows = e.buffer.rows.items.len;

    switch (want) {
        .set => {
            V.cwant = if (V.cy < numrows) e.currentRow().cxToRx(V.cx) else 0;
        },
        .maxcol => {
            V.cwant = maxUsize;
        },
        .restore => {
            if (V.cy == numrows) { // past end of file
                V.cx = 0;
            }
            else if (V.cwant == maxUsize) { // wants end of line
                V.cx = e.currentRow().clen();
            }
            else {
                const row = e.currentRow();
                const rowlen = row.clen();
                if (rowlen == 0) {
                    V.cx = 0;
                }
                else {
                    // cwant is an index of the rendered column, must convert
                    V.cx = row.rxToCx(V.cwant);
                    if (V.cx > rowlen) {
                        V.cx = rowlen;
                    }
                }
            }
        },
    }
}

/// Scroll the view, respecting scroll_off.
fn scroll(e: *Editor) void {
    const V = &e.view;
    const numrows = e.buffer.rows.items.len;

    //////////////////////////////////////////
    //          scrolloff option
    //////////////////////////////////////////

    if (opt.scroll_off > 0 and numrows > e.screen.rows) {
        while (V.rowoff + e.screen.rows < numrows
               and V.cy + opt.scroll_off >= e.screen.rows + V.rowoff)
        {
            V.rowoff += 1;
        }
        while (V.rowoff > 0 and V.rowoff + opt.scroll_off > V.cy) {
            V.rowoff -= 1;
        }
    }

    //////////////////////////////////////////
    //          update rendered column
    //////////////////////////////////////////

    V.rx = 0;

    if (V.cy < numrows) {
        V.rx = e.currentRow().cxToRx(V.cx);
    }

    //////////////////////////////////////////
    //      update rowoff and coloff
    //////////////////////////////////////////

    // cursor has moved above the visible window
    if (V.cy < V.rowoff) {
        V.rowoff = V.cy;
    }
    // cursor has moved below the visible window
    if (V.cy >= V.rowoff + e.screen.rows) {
        V.rowoff = V.cy - e.screen.rows + 1;
    }
    // cursor has moved beyond the left edge of the window
    if (V.rx < V.coloff) {
        V.coloff = V.rx;
    }
    // cursor has moved beyond the right edge of the window
    if (V.rx >= V.coloff + e.screen.cols) {
        V.coloff = V.rx - e.screen.cols + 1;
    }
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Screen update
//
///////////////////////////////////////////////////////////////////////////////

/// Full refresh of the screen.
fn refreshScreen(e: *Editor) !void {
    e.scroll();

    e.surface.clearRetainingCapacity();

    try e.toSurface(ansi.BgDefault);
    try e.toSurface(ansi.HideCursor);
    try e.toSurface(ansi.CursorTopLeft);

    try e.drawRows();
    try e.drawStatusline();
    try e.drawMessageBar();

    const V = &e.view;

    // move cursor to its current position (could have been moved with keys)
    var buf: [32]u8 = undefined;
    const row = V.cy - V.rowoff + 1;
    const col = V.rx - V.coloff + 1;
    try e.toSurface(try ansi.moveCursorTo(&buf, row, col));

    try e.toSurface(ansi.ShowCursor);

    e.just_started = false;
    try linux.write(e.surface.items);
}

/// Append rows to be drawn to the surface. Handles escape sequences for syntax
/// highlighting.
fn drawRows(e: *Editor) !void {
    const V = &e.view;
    const rows = e.buffer.rows.items;

    for (0 .. e.screen.rows) |y| {
        const ix: usize = y + V.rowoff;

        // past buffer content
        if (ix >= rows.len) {
            if (e.just_started
                and e.buffer.filename == null
                and e.buffer.rows.items.len == 0
                and y == e.screen.rows / 3) {
                try e.toSurface(e.welcome_msg.items);
            }
            else {
                try e.toSurface('~');
            }
        }
        // within buffer content
        else {
            // length of the rendered line
            const rowlen = rows[ix].render.len;

            // actual length that should be drawn because visible
            var len = if (V.coloff > rowlen) 0 else rowlen - V.coloff;
            len = @min(len, e.screen.cols);

            // part of the line after coloff, and its highlight
            const rline = if (len > 0) rows[ix].render[V.coloff..] else &.{};
            const hl = if (len > 0) rows[ix].hl[V.coloff..] else &.{};

            var current_color = t.Highlight.normal;

            // loop characters of the rendered row
            for (rline[0..len], 0..) |c, i| {
                if (c != '\t' and !asc.isPrint(c)) {
                    // for example, turn Ctrl-A into 'A' with reversed colors
                    current_color = t.Highlight.nonprint;
                    try e.toSurface(t.HlGroup.attr(.nonprint));
                    try e.toSurface(switch (c) {
                        0...26 => '@' + c,
                        else => '?',
                    });
                }
                else if (hl[i] != current_color) {
                    const color = hl[i];
                    current_color = color;
                    try e.toSurface(t.HlGroup.attr(color));
                }
                try e.toSurface(c);
            }
            // end of the line, reset highlight
            try e.toSurface(ansi.ResetColors);
        }
        try e.toSurface(ansi.ClearLine);
        try e.toSurface("\r\n"); // end the line
    }
}

/// Append the statusline to the surface.
fn drawStatusline(e: *Editor) !void {
    const V = &e.view;

    try e.toSurface(ansi.ReverseColors);

    var lbuf: [200]u8 = undefined;
    var rbuf: [80]u8 = undefined;

    // left side of the statusline
    var ls = std.fmt.bufPrint(&lbuf, "{s} - {} lines{s}", .{
        e.buffer.filename orelse "[No Name]",
        e.buffer.rows.items.len,
        if (e.buffer.dirty) " [modified]" else "",
    }) catch "";

    // right side of the statusline (leading space to guarantee separation)
    var rs = std.fmt.bufPrint(&rbuf, " | {s} | col {}, ln {}/{} ", .{
        e.buffer.syntax orelse "no ft",
        V.cx + 1,
        V.cy + 1,
        e.buffer.rows.items.len,
    }) catch "";

    var room_left = e.screen.cols;

    // prioritize left side
    if (ls.len > room_left) {
        ls = ls[0 .. room_left];
    }
    room_left -= ls.len;

    try e.toSurface(ls);

    if (room_left == 0) {
        try e.finalizeStatusline();
        return;
    }

    // add right side and spaces if there is room left for them
    if (rs.len > room_left) {
        rs = rs[0 .. room_left];
    }
    room_left -= rs.len;

    try e.surface.appendNTimes(e.alc, ' ', room_left);
    try e.toSurface(rs);
    try e.finalizeStatusline();
}

/// Reset colors and append new line after statusline
fn finalizeStatusline(e: *Editor) !void {
    try e.toSurface(ansi.ResetColors);
    try e.toSurface("\r\n");
}

/// Append the message bar to the surface.
fn drawMessageBar(e: *Editor) !void {
    try e.toSurface(ansi.ClearLine);

    var msglen = e.status_msg.items.len;
    if (msglen > e.screen.cols) {
        msglen = e.screen.cols;
    }
    if (msglen > 0 and time() - e.status_msg_time < 5) {
        try e.toSurface(e.status_msg.items[0 .. msglen]);
    }
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Message area
//
///////////////////////////////////////////////////////////////////////////////

/// Start a prompt in the message area, return the user input.
/// Prompt is terminated with either .esc or .enter keys.
/// Prompt is also terminated by .backspace if there is no character left in
/// the input.
fn promptForInput(e: *Editor, prompt: []const u8) !t.Chars {
    var al = try t.Chars.initCapacity(e.alc, 80);

    while (true) {
        try e.statusMessage("{s}{s}", .{ prompt, al.items });
        try e.refreshScreen();

        const k = try ansi.readKey();
        const c = @intFromEnum(k);

        switch (k) {
            .ctrl_h, .backspace => {
                if (al.items.len == 0) {
                    break;
                }
                _ = al.pop();
            },

            .esc => {
                al.clearRetainingCapacity();
                break;
            },

            .enter => break,

            else => if (k == .tab or asc.isPrint(c)) {
                try al.append(e.alc, c);
            },
        }
    }
    e.clearStatusMessage();
    return al;
}

/// Set a status message, using regular highlight.
pub fn statusMessage(e: *Editor, comptime format: []const u8, args: anytype) !void {
    assert(format.len > 0);
    e.status_msg.clearRetainingCapacity();
    try e.status_msg.print(e.alc, format, args);
    e.status_msg_time = time();
}

/// Print an error message, using error highlight.
pub fn errorMessage(e: *Editor, comptime format: []const u8, args: anytype) !void {
    assert(format.len > 0);
    e.status_msg.clearRetainingCapacity();
    const fmt = comptime t.HlGroup.attr(.err) ++ format ++ ansi.ResetColors;
    try e.status_msg.print(e.alc, fmt, args);
    e.status_msg_time = time();
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Syntax highlighting
//
///////////////////////////////////////////////////////////////////////////////

/// Update highlight for a row.
fn updateHighlight(e: *Editor, ix: usize) !void {
    const row = e.rowAt(ix);

    // reset the row highlight to normal
    row.hl = try e.alc.realloc(row.hl, row.render.len);
    @memset(row.hl, .normal);
}

///////////////////////////////////////////////////////////////////////////////
//
//                              Helpers
//
///////////////////////////////////////////////////////////////////////////////

/// Update the string, freeing the old one and allocating from `path`.
fn updateString(e: *Editor, old: ?[]u8, path: []const u8) ![]u8 {
    t.freeOptional(e.alc, old);
    return try e.alc.dupe(u8, path);
}

/// Get the row pointer at index `ix`.
fn rowAt(e: *Editor, ix: usize) *t.Row {
    return &e.buffer.rows.items[ix];
}

/// Get the row pointer at cursor position.
fn currentRow(e: *Editor) *t.Row {
    return &e.buffer.rows.items[e.view.cy];
}

/// Generate the welcome message.
fn generateWelcome(e: *Editor) !void {
    try e.welcome_msg.append(e.alc, '~');

    var msg = message.status.get("welcome").?;
    if (msg.len >= e.screen.cols) {
        msg = msg[0 .. e.screen.cols - 1];
    }
    const padding: usize = (e.screen.cols - msg.len) / 2;

    try e.welcome_msg.appendNTimes(e.alc, ' ', padding);
    try e.welcome_msg.appendSlice(e.alc, msg);
}

/// Append either a slice or a character to the editor surface.
fn toSurface(e: *Editor, value: anytype) !void {
    switch (@typeInfo(@TypeOf(value))) {
        .pointer => try e.surface.appendSlice(e.alc, value),
        else => try e.surface.append(e.alc, value),
    }
}

/// Clear the message area. Can't fail because it won't reallocate.
fn clearStatusMessage(e: *Editor) void {
    e.status_msg.clearRetainingCapacity();
}

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

///////////////////////////////////////////////////////////////////////////////
//
//                              Constants, variables
//
///////////////////////////////////////////////////////////////////////////////

const Editor = @This();

const std = @import("std");

const t = @import("types.zig");
const ansi = @import("ansi.zig");
const opt = @import("option.zig");
const linux = @import("linux.zig");
const message = @import("message.zig");
const str = @import("string.zig");

const mem = std.mem;
const asc = std.ascii;

const expect = std.testing.expect;
const assert = std.debug.assert;

const time = std.time.timestamp;
const time_ms = std.time.milliTimestamp;

const initial_msg_size = 80;
const maxUsize = std.math.maxInt(usize);
