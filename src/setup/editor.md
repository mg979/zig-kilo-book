# Setup an editor

You will also need a text editor, before you can use your own. Which you
shouldn't do anyway, so you need an editor.

I recommend you don't use any advanced tooling, like
[zls](https://github.com/zigtools/zls). I think that while still learning it's
better not to use them, I find it's enough to rely on what the compiler tells
you, then find and fix the mistakes by yourself.

## ctags

Instead, if you use an editor that supports tags, I think it's a good idea to
use them, to navigate faster between functions, types and other parts of our
project. To use tags you must have `universal-ctags` installed, for example in
Debian/Ubuntu you install it with:

    sudo apt install universal-ctags

But `ctags` doesn't support natively Zig, so you should create a file at
`~/.config/ctags/zig.ctags` with this content:

```ctags
--langdef=zig
--map-zig=.zig

--kinddef-zig=f,function,functions
--kinddef-zig=m,method,methods
--kinddef-zig=t,type,types
--kinddef-zig=v,field,fields

# functions
--regex-zig=/^(export +)?(pub +)?(inline +)?(extern .+ )?fn +([a-zA-Z0-9_]+)/\5/f/{exclusive}

# structs, union, enum
--regex-zig=/^(export +)?(pub +)?[\t ]*const +([a-zA-Z0-9_]+) = (struct|enum|union)/\3/t/{exclusive}{scope=push}
--regex-zig=/^}///{exclusive}{scope=pop}{placeholder}

# methods
--regex-zig=/^[\t ]+(pub +)?(inline +)?fn +([a-zA-Z0-9_]+)/\3/m/{exclusive}{scope=ref}

# public constants/variables
--regex-zig=/^(export +)?pub +(const|var) +([a-zA-Z0-9_]+)(:.*)? = .*/\3/v/{exclusive}
```
