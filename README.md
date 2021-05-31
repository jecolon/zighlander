# Zighlander - There Can Be Only One
Zighlander is a little Zig generic function that implements what in Object Oriented circles is
known as the *Singleton Pattern*. The intention is to make it easy to manage the lifecycle of *heavy* 
data structures that should only be instantiated once. An atomic reference count keeps track of 
active references and when it reaches 0, the singleton instance is destroyed.

Initialization, if necessary, has to be done manually after the first call to `get`, as this first
call will just return the pointer to the reserved memory for your data, which will be undefined at that
point. You must initialize and assign your data to this memory area via the returned pointer.

Likewise, once you're done with your data, you must de-initialize it if necessary before it is
destroyed automatically by `Zighlander.deinit` or the call to `put` that takes the reference count dwon
to 0.

## Thread-Safety
The only safe way to use this pattern in a multi-threaded program is to guarantee that

1. Only one thread initializes the singleton after the first call to the `get` method.
2. All other references are only used for read-only access to the singleton.
3. Only one thread de-initializes the singleton when it is no longer needed.

If these conditions are strictly met, race-conditions are avoided. Even so, the singleton pattern is
not a good fit for multi-threaded programming in general, so we don't recommend using Zighlander in 
such programs.

## Integrating Zighlander in your Project
In a `libs` subdirectory under the root of your project, clone this repository via

```sh
$  git clone https://github.com/jecolon/zighlander.git
```

Now in your build.zig, you can add:

```zig
exe.addPackagePath("Zighlander", "libs/zighlander/src/zighlander.zig");
```

to the `exe` section for the executable where you wish to have Zighlander available. Now in the code, you
can import the function like this:

```zig
const Zighlander = @import("Zighlander").Zighlander;
```

Finally, you can build the project with:

```sh
$ zig build
```

Note that to build in realase modes, either specify them in the `build.zig` file or on the command line
via the `-Drelease-fast=true`, `-Drelease-small=true`, `-Drelease-safe=true` options to `zig build`.

## Usage
```zig
const Zighlander = @import("Zighlander").Zighlander;

test "Zighlander" {
    var allocator = std.testing.allocator;

    // Create the unique Zighlander to manage the singleton.
    var only_one = Zighlander(std.ArrayList(u8)).init(allocator);

    // This deinit on the Zighlander itself will destroy the singleton no matter how many references
    // are still active. If you don't want this behavior, omit this defer call and manage the references
    // with the get and put methods as shown below. Even if you manage the references with get and
    // put, you can still make this defer to ensure clean up on program exit.
    defer only_one.deinit();

    // Call get to retrieve a reference to the singleton instance.
    var one = try only_one.get();

    // NOTE! The first time you get a reference, you must initialize it because it's just a pointer
    // to garbage memory. Failure to do this will result in either crashes or undefined behavior.
    one.* = std.ArrayList(u8).init(allocator);

    // Likewise, make sure to deinit your data if necessary when you're done with it.
    defer one.deinit();

    // Changes made to the singleton will be seen by all references to it. NOTE! The reference counting
    // is thread-safe thanks to atomics, but the singleton instance itself is NOT thread-safe.
    for ([3]u8{ 1, 2, 3 }) |i| {
        try one.append(i);
    }

    // Grab another reference to the singleton instance.
    var two = try only_one.get();

    // The put method decremets the reference counter. This does not actually invalidate any active 
    // references, unless the counter reaches 0, at which point the singleton will be de-initialized 
    // and destroyed. 
    defer only_one.put();

    // You can check if references are still valid with the isNull methodd.
    testing.expect(!only_one.isNull());

    // Modifications on reference 'one' are visible through reference 'two'.
    testing.expect(two.items.len == 3);
}
```
