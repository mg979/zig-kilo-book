Built with:

- mdbook version v0.4.52
- mdbook-admonish v1.20.0

Public URL: https://mg979.github.io/zig-kilo-book

Main repo of the editor (unrelated to this repo): https://codeberg.org/gmbajo/kilo.zig

### Code

If you're in a hurry, or you just want to try it out, or any other reason, and
you don't want to type the code yourself, in the `code` branch there's the full
code, where each commit is the code until the chapter with the commit name.

To only download the code:

    git clone --branch code --single-branch https://github.com/mg979/zig-kilo-book.git

The first commit has the `start` tag. So you could do:

    git checkout start

Then move to the next commit (chapter) with:

    git checkout $(git rev-list --topo-order code ^HEAD | tail -1)

You can then have a diff with the previous commit with:

    git diff HEAD^ HEAD

You can also do this to compare it with your current code, to be sure you
didn't forget anything.

-------------------------------------------------------------------------------

**NOTE**: not all commits can compile successfully. When it can't, most of the
times, the commit name has the `[nc]` suffix, but surely I forgot some.
