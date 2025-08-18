# Searching

Now that we can prompt the user for input, and we can apply highlight to the
text, we could give our editor the capability to search for words in the file.

To be able to do this, we'll need several changes. We defined the `incsearch`
highlight, so we don't need to do that.

Instead, we must change how `promptForInput()` works. Until now, it only
prompted a string from the user and returned it, without doing anything in
between.

Now instead we want that every time the user types a character, the currently
typed pattern will be searched, and if found it will be given a highlight on
the screen.

