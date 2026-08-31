const std = @import("std");

/// Prevents the compiler from optimizing away a value or computation and returns the value.
/// Uses Zig's standard compiler memory and register barrier.
pub fn blackBox(val: anytype) @TypeOf(val) {
    std.mem.doNotOptimizeAway(val);
    return val;
}

test "blackBox identity" {
    const x: u64 = 42;
    const res = blackBox(x);
    try std.testing.expectEqual(x, res);
}
