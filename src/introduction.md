# Introduction

Some years ago a booklet has been published, called [Build your own text
editor](https://viewsourcecode.org/snaptoken/kilo/index.html), a guide to
create a minimal text editor from scratch in the C programming language, based
on the code of the [kilo editor](https://github.com/antirez/kilo). It's a fun
exercise to learn some C programming, because writing a toy text editor is fun.

In my attempt at learning the Zig programming language, I thought that
rewriting that editor in Zig would have been a good exercise as well, and since
learning resources for Zig aren't overly abundant, I thought it would have been
a good idea to write a guide on how to do it, step by step, following the
example of the booklet I mentioned before.

I want to make it clear that I'm neither an expert Zig programmer (this was my
first Zig program), or an expert programmer in general (I'm self-taught and
I just dabble with programming so to speak), so don't expect great technical
insights or elaborate programming techniques, it's not the purpose of this
document anyway. Moreover, I never claim that the way I solve a particular
problem in this program is the best way to solve it, neither that it's the one
that is the most idiomatic to the Zig programming language. Like its own
predecessor, the C programming language, Zig is rather free-form in the sense
that it doesn't enforce a particular programming style or paradigm. Still, also
Zig has its idioms and best practices, and I try to follow them in general, but
sometimes I will also show different ways to approach the same problem.

As a matter of fact, in this guide I don't strive to find the optimal
solutions, from the point of view of performance optimizations and memory usage
for example, but generally the simplest ones that I consider still acceptable.
It is a _minimal_ text editor, after all.

Also remember that the program we're creating is just a toy, an exercise to
learn something more about a programming language, and not a tool that can have
any serious use.

Compared to the original C version, here we will not respect the 1024 lines of
code limit (from which the name `kilo` stems) and we will not be limited to
a single file, since pursuing (or even worse _achieving_) such coinciseness
would preclude us from using many useful features of the Zig programming
language, such as importable modules and instantiable types. Having everything
in a single file might make sense for small libraries, but it's not what we're
doing here.

I do sometimes use collapsible notes:

```admonish note collapsible=true
Heya!
```

Speaking of the knowledge required to understand this booklet, this is not
a programming guide but rather an exercise, so I will expect that you have at
least some notion in systems programming languages like C, in the sense that
I will suppose that you know already what pointers are and how to use them, or
anything that can be considered basic programming knowledge.

I will also expect that you know the basics of the Zig programming language, so
if you didn't already, I suggest that you go through the exercises from the
[ziglings](https://codeberg.org/ziglings/exercises/#ziglings) project before
attempting this one. Other learning resources that I found useful are (in no
particular order):

- [Zig on exercism.org](https://exercism.org/tracks/zig)
- [Learning Zig](https://www.openmymind.net/learning_zig/)
- [Zig Cookbook](https://cookbook.ziglang.cc/intro.html)
- [zig.guide](https://zig.guide/) (slightly outdated)

and the most important of all, always up to date:

- [The official Zig language
reference](https://ziglang.org/documentation/master/)
- [The std library documentation](https://ziglang.org/documentation/master/std/)
