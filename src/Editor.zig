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
        var al = try e.promptForInput(message.prompt.get("fname").?, .{}, null);
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

        .ctrl_f => try e.find(),

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
//                              Find
//
///////////////////////////////////////////////////////////////////////////////

/// Start the search prompt.
fn find(e: *Editor) !void {
    const saved = e.view;
    var query = try e.promptForInput("/", saved, findCallback);
    query.deinit(e.alc);
}

/// Called by promptForInput() for every valid inserted character.
/// The saved view is restored when the current query isn't found, or when
/// backspace clears the query, so that the search starts from the original
/// position.
fn findCallback(e: *Editor, ca: t.PromptCbArgs) t.EditorError!void {
    const static = struct {
        var found: bool = false;
        var view: t.View = .{};
        var pos: t.Pos = .{};
        var oldhl: []t.Highlight = &.{};
    };

    const empty = ca.input.items.len == 0;
    const numrows = e.buffer.rows.items.len;

    // restore line highlight before incsearch highlight, or clean up
    if (static.oldhl.len > 0) {
        @memcpy(e.rowAt(static.pos.lnr).hl, static.oldhl);
    }

    // clean up
    if (ca.final) {
        e.alc.free(static.oldhl);
        static.oldhl = &.{};
        if (empty or ca.key == .esc) {
            e.view = ca.saved;
        }
        if (!static.found and ca.key == .enter) {
            try e.statusMessage("No match found", .{});
        }
        static.found = false;
        return;
    }

    // Query is empty so no need to search, but restore position
    if (empty) {
        static.found = false;
        e.view = ca.saved;
        return;
    }

    // when pressing backspace we restore the previously saved view
    // cursor might move or not, depending on whether there is a match at
    // cursor position
    if (ca.key == .backspace or ca.key == .ctrl_h) {
        e.view = static.view;
    }

    //////////////////////////////////////////
    //   Find the starting position
    //////////////////////////////////////////

    const V = &e.view;

    const prev = ca.key == .ctrl_t;
    const next = ca.key == .ctrl_g;

    // current cursor position
    var pos = t.Pos{ .lnr = V.cy, .col = V.cx };

    const eof = V.cy == numrows;
    const last_char_in_row = !eof and V.rx == e.currentRow().render.len;
    const last_row = V.cy == numrows - 1;

    // must move the cursor forward before searching when we don't want to
    // match at cursor position
    const step_fwd = ca.key != .backspace and (next or empty or !static.found);

    if (step_fwd) {
        if (eof or (last_row and last_char_in_row)) {
            if (!opt.wrapscan) { // restart from the beginning of the file?
                return;
            }
        }
        else if (last_char_in_row) { // start searching from next line
            pos.lnr = V.cy + 1;
        }
        else { // start searching after current column
            pos.col = V.cx + 1;
            pos.lnr = V.cy;
        }
    }

    //////////////////////////////////////////
    //          Start the search
    //////////////////////////////////////////

    var match: ?[]const u8 = null;

    if (!prev) {
        match = e.findForward(ca.input.items, &pos);
    }
    else {
        match = e.findBackward(ca.input.items, &pos);
    }

    // If wrapscan, no problems: no match is no match.
    // Otherwise it can be that we had a match, but another one isn't found in
    // the current searching direction: then we only update static.found if:
    // - either not pressing ctrl-g or ctrl-t (next or prev)
    // - or we didn't have a match to begin with
    if (opt.wrapscan or !(next or prev) or !static.found) {
        static.found = match != null;
    }

    const row = e.rowAt(pos.lnr);

    if (match) |m| {
        V.cy = pos.lnr;
        V.cx = &m[0] - &row.chars.items[0];

        static.view = e.view;
        static.pos = .{ .lnr = pos.lnr, .col = V.cx };

        // first make a copy of current highlight, to be restored later
        static.oldhl = try e.alc.realloc(static.oldhl, row.render.len);
        @memcpy(static.oldhl, row.hl);

        // apply search highlight
        const start = row.cxToRx(V.cx);
        const end = row.cxToRx(V.cx + m.len);
        @memset(row.hl[start .. end], t.Highlight.incsearch);
    }
    else if (!opt.wrapscan and static.found and (next or prev)) {
        // the next match wasn't found in the searching direction
        // we still set the highlight for the current match, since the original
        // highlight has been restored at the top of the function
        // this can definitely happen with !wrapscan
        const start = row.cxToRx(static.pos.col);
        const end = row.cxToRx(static.pos.col + ca.input.items.len);
        @memset(row.hl[start .. end], t.Highlight.incsearch);
    }
    else {
        // a match wasn't found because the input couldn't be found
        // restore the original view (from before the start of the search)
        e.view = ca.saved;
    }
}

/// Start a search forwards.
fn findForward(e: *Editor, query: []const u8, pos: *t.Pos) ?[]const u8 {
    var col = pos.col;
    var i = pos.lnr;

    while (i < e.buffer.rows.items.len) : (i += 1) {
        const rowchars = e.rowAt(i).chars.items;

        if (indexOf(u8, rowchars[col..], query)) |m| {
            pos.lnr = i;
            return rowchars[(col + m)..(col + m + query.len)];
        }

        col = 0; // reset search column
    }

    if (!opt.wrapscan) {
        return null;
    }

    // wrapscan enabled, search from start of the file to current row
    i = 0;
    while (i <= pos.lnr) : (i += 1) {
        const rowchars = e.rowAt(i).chars.items;

        if (indexOf(u8, rowchars, query)) |m| {
            pos.lnr = i;
            return rowchars[m .. m + query.len];
        }
    }
    return null;
}

/// Start a search backwards.
fn findBackward(e: *Editor, query: []const u8, pos: *t.Pos) ?[]const u8 {
    // first line, search up to col
    const row = e.rowAt(pos.lnr);
    const col = pos.col;
    var rowchars = row.chars.items;
    var i: usize = undefined;

    if (lastIndexOf(u8, rowchars[0..col], query)) |m| {
        return rowchars[m .. m + query.len];
    }
    else if (pos.lnr > 0) {
        // previous lines, search full line
        i = pos.lnr - 1;
        while (true) : (i -= 1) {
            rowchars = e.rowAt(i).chars.items;

            if (lastIndexOf(u8, rowchars, query)) |m| {
                pos.lnr = i;
                return rowchars[m .. m + query.len];
            }
            if (i == 0) break;
        }
    }

    if (!opt.wrapscan) {
        return null;
    }

    i = e.buffer.rows.items.len - 1;
    while (i > pos.lnr) : (i -= 1) {
        rowchars = e.rowAt(i).chars.items;

        if (lastIndexOf(u8, rowchars, query)) |m| {
            pos.lnr = i;
            return rowchars[m .. m + query.len];
        }
    }

    // check again the starting line, this time in the part after the offset
    rowchars = e.rowAt(pos.lnr).chars.items;

    if (lastIndexOf(u8, rowchars[col..], query)) |m| {
        // m is the index in the substring starting from `col`, therefore we
        // must add `col` to get the real index in the row
        return rowchars[m + col .. m + col + query.len];
    }
    return null;
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
/// At each keypress, the prompt callback is invoked, with a final invocation
/// after the prompt has been terminated with either .esc or .enter keys.
/// Prompt is also terminated by .backspace if there is no character left in
/// the input.
fn promptForInput(e: *Editor, prompt: []const u8, saved: t.View, cb: ?t.PromptCb) !t.Chars {
    var al = try t.Chars.initCapacity(e.alc, 80);

    var k: t.Key = undefined;
    var c: u8 = undefined;
    var cb_args: t.PromptCbArgs = undefined;

    while (true) {
        try e.statusMessage("{s}{s}", .{ prompt, al.items });
        try e.refreshScreen();

        k = try ansi.readKey();
        c = @intFromEnum(k);
        cb_args = .{ .input = &al, .key = k, .saved = saved };

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
        if (cb) |callback| try callback(e, cb_args);
    }
    e.clearStatusMessage();
    cb_args.final = true;
    if (cb) |callback| try callback(e, cb_args);
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

const lastIndexOf = mem.lastIndexOf;
const indexOf = mem.indexOf;

const time = std.time.timestamp;
const time_ms = std.time.milliTimestamp;

const initial_msg_size = 80;
const maxUsize = std.math.maxInt(usize);
