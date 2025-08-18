# Reading and Writing

Before we can draw anything, we must be able to open a file, read all of its
lines and store them in our Buffer.

In `main()`, the first command line argument is passed to the
`Editor.startUp()` function. If it is non-null, the file will be opened if
existing.

To handle read/write operations, we'll use the `Io.Reader` and `Io.Writer`
interfaces. They have methods to process incoming/outcoming data and can do
buffered reading and writing. They are _interfaces_, meaning that independently
from what they are attached to, they have the same way of operating. So if you
read from _stdin_ or from a file, you'll have access to the same ways of
processing data.

They have been only recently added to the Zig standard library and are a vast
subject, so I will only mention that they exist, and that we'll be using them
for some tasks.

For now we can only read a file, because we don't have the means to fill our
Buffer rows yet.
