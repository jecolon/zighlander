//! Zighlander is a Zig implementation of the Singleton Pattern.

const std = @import("std");
const atomic = std.atomic;
const mem = std.mem;
const testing = std.testing;

/// Create a new Zighlander to manage a singleton of type T.
pub fn Zighlander(comptime T: type) type {
    return struct {
        const Self = @This();

        const Singleton = struct {
            instance: *T,
            ref_count: atomic.Atomic(usize),
        };

        allocator: *mem.Allocator,
        singleton: ?Singleton,

        /// Initialize the Zighlander, not the contained singleton.
        pub fn init(allocator: *mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .singleton = null,
            };
        }

        /// get a reference to the singleton. Creates a new singleton if necessary, which must then
        /// be initialized by the caller.
        pub fn get(self: *Self) !*T {
            if (self.singleton) |*s| {
                _ = s.ref_count.fetchAdd(1, .SeqCst);
                return s.instance;
            }

            self.singleton = Singleton{
                .instance = try self.allocator.create(T),
                .ref_count = atomic.Atomic(usize).init(1),
            };

            return self.singleton.?.instance;
        }

        /// put decrements the reference counter, de-initializing and destroying the singleton if it
        /// reaches zero.
        pub fn put(self: *Self) void {
            if (self.singleton) |*s| {
                if (s.ref_count.fetchSub(1, .SeqCst) == 1) self.deinit();
            }
        }

        /// destroy the singleton, unconditionally, regardless of reference count.
        pub fn deinit(self: *Self) void {
            if (self.singleton) |*s| {
                self.allocator.destroy(s.instance);
                self.singleton = null;
            }
        }

        /// isNull checks if the singleton is there.
        pub fn isNull(self: Self) bool {
            return self.singleton == null;
        }
    };
}

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

    // The put method decremets the reference counter by 1; when it reaches 0, the singleton instance
    // will be de-initialized and destroyed.
    defer only_one.put();

    // You can check if references are still valid with the isNull methodd.
    try testing.expect(!only_one.isNull());

    // Modifications on reference 'one' are visible through reference 'two'.
    try testing.expect(two.items.len == 3);
}
