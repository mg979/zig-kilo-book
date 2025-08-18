# Getting the window size

```admonish note
Before we proceed, delete the last 2 lines in the main functions (the ones that
read the from input) and the `readChar()` function as well, we won't need them
anymore.
```

We went past raw mode, which was possibly annoying. Unfortunately we must take
care of the low level code before we can proceed to code the actual editor.
And there's still a good bit to come.

Before we can draw anything on the screen, we must know its size, the number of
rows and columns.

There are two ways to do this, with the second method that will be attempted in
the case that the first one fails.

The first method involves calling the linux `ioctl` function to request the
window size from the operating system.

The fallback method involves determining the cursor position in a maximized
window.
