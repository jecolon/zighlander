const std = @import("std");
const atomic = std.atomic;
const mem = std.mem;
const testing = std.testing;

pub fn Zighlander(comptime T: type) type {
    return struct {
        const Self = @This();

        const Singleton = struct {
            instance: *T,
            ref_count: atomic.Int(usize),
        };

        allocator: *mem.Allocator,
        singleton: ?Singleton,

        pub fn init(allocator: *mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .singleton = null,
            };
        }

        pub fn get(self: *Self) !*T {
            if (self.singleton) |*s| {
                _ = s.ref_count.incr();
                return s.instance;
            }

            self.singleton = Singleton{
                .instance = try self.allocator.create(T),
                .ref_count = atomic.Int(usize).init(1),
            };

            return self.singleton.?.instance;
        }

        pub fn put(self: *Self) void {
            if (self.singleton) |*s| {
                if (s.ref_count.decr() == 1) self.deinit();
            }
        }

        pub fn deinit(self: *Self) void {
            if (self.singleton) |*s| {
                s.instance.deinit();
                self.allocator.destroy(s.instance);
                self.singleton = null;
            }
        }
    };
}

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
