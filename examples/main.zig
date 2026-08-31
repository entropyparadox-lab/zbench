const std = @import("std");
const zbench = @import("zbench");

fn fibonacci(n: u64) u64 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

fn benchFibonacci() void {
    _ = zbench.blackBox(fibonacci(20));
}

fn benchSha256() void {
    var data: [1024]u8 = undefined;
    @memset(&data, 0x42);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data, &hash, .{});
    _ = zbench.blackBox(hash);
}

fn benchSorting() void {
    var array: [256]u32 = undefined;
    for (&array, 0..) |*item, idx| {
        item.* = @as(u32, @intCast(256 - idx));
    }
    std.mem.sort(u32, &array, {}, comptime std.sort.asc(u32));
    _ = zbench.blackBox(array);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var suite = zbench.BenchmarkSuite.init(allocator);
    defer suite.deinit();

    try suite.add("Fibonacci(20)", benchFibonacci, .{
        .warmup_ms = 100,
        .sample_count = 50,
    });

    try suite.add("SHA256 (1KB Buffer)", benchSha256, .{
        .warmup_ms = 100,
        .sample_count = 50,
        .bytes_per_op = 1024,
    });

    try suite.add("QuickSort (256 integers)", benchSorting, .{
        .warmup_ms = 100,
        .sample_count = 50,
    });

    try suite.run();
}
