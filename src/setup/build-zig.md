# The Zig build system

From now on, I'll assume the directory of the project is located in
`~/kilo-zig`.

    cd ~/kilo-zig

After having initialized the project with `zig init` inside that directory,
a bunch of files will have been created. We don't need the `src/root.zig` file,
because that is only useful if we are creating a library, and we're not, so we
delete it:

    rm src/root.zig

We'll also have to edit the `build.zig` file, which is the zig equivalent of
a Makefile. I will not go into details about how the zig build system works,
because I barely know it myself. What matters now is that currently the default
build file is unsuitable to build our project. If we open it, we'll see that it
does several things:

- it defines build options
- it defines a module (`mod` that points at `src/root.zig`)
- it defines a main executable (`exe` that points at `src/main.zig`)
- it adds steps for tests for both main executable and module

We'll have to remove all the steps that would build a module. So you remove:

- the `mod` variable
- the `.imports` field in the `.addExecutable()` argument
- other lines with `mod`: `mod_tests`, `run_mod_tests` and so on

You'll also rename `exe.name` to `kilo`.

This is the final `build.zig` with most comments removed:

<div class="code-title">build.zig</div>

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function.
    const exe = b.addExecutable(.{
        .name = "kilo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // By default the install prefix is `zig-out/` but can be overridden by
    // passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the executable's
    // root module.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
```
