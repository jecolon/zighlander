# Zighlander - There Can Be Only One
Zighlander is a little Zig generic function that implements what in Object Oriented circles is
known as the *Singleton Pattern*. The intention is to make it easy to manage the lifecycle of *heavy* 
data structures that should only be instantiated once. An atomic reference count keeps track of 
active references and when it reaches 0, `deinit` is called on the singleton and then destroyed.
Thus, the singleton struct must have a `deinit` method that takes no arguments apart from the pointer
to `@This()` and returns void with no error (pretty much idiomatic in Zig.) Initialization via an 
`init` (or whatever other name) function has to be done manually after the first call to `get`, 
allowing for any type of function signature to be used. See example below.

## Thread-Safety
The only safe way to use this pattern in a multi-threaded program is to guarantee that

1. Only one thread initializes the singleton after the first call to the `get` method.
2. All other references are only used for read-only access to the singleton.

If these conditions are strictly met, race-conditions are avoided.

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

    // This deinit on the Zighlander itself will deinit and destroy the singleton no matter how 
    // many references are still active. If you don't want this behavior, omit this defer call and 
    // manage the references with the get and put methods as shown below. Even if you manage the 
    // references with get and put, you can still make this defer to ensure clean up at program end.
    defer only_one.deinit();

    // Call get to retrieve a reference to the singleton instance.
    var one = try only_one.get();

    // NOTE! The first time you get a reference, you must initialize it because it's just a pointer
    // to garbage memory. Failure to do this will result in either crashes or undefined behavior.
    one.* = std.ArrayList(u8).init(allocator);

    // Changes made to the singleton will be seen by all references to it. NOTE! The reference counting
    // is thread-safe thanks to atomics, but the singleton instance itself is NOT thread-safe.
    for ([3]u8{ 1, 2, 3 }) |i| {
        try one.append(i);
    }

    // Grab another reference to the singleton instance.
    var two = try only_one.get();

    // The put method decremets the reference counter by 1; when it reaches 0, the singleton instance
    // will be de-initialized and destroyed.
    defer only_one.put();

    // Modifications on reference 'one' are visible through reference 'two'.
    testing.expect(two.items.len == 3);
}
```
