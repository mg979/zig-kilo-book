# Setup

This program was written in a Linux environment, for the Linux environment.
Therefore if you use Windows you should install WSL2 and a Linux distribution
(I tested it on Ubuntu Preview). I don't think it can work on MacOS, but you're
free to try, and anyway it would not be too difficult to make it work there in
the future.

## Install zig

First thing, you need Zig itself. If you don't have it, or if you have
a different version installed, you can download it
[here](https://ziglang.org/download/). Currently this document uses the `0.15.1` release, so it's the one
that you should download.

Decompress the archive somewhere, for example in `~/.local/zig`:

    tar xf <archive> --directory=/home/username/.local
    mv <name-of-extracted-directory> zig

Then add this directory to your path by adding this to your `.bashrc`

    export PATH=$PATH:~/.local/zig

Now start a new terminal instance and see if `zig` is in your path:

    zig version

And it should print

    0.15.1

Finally, choose a directory for your project and initialize it:

    mkdir kilo-zig
    cd kilo-zig
    zig init

