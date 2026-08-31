const std = @import("std");

pub const blackbox = @import("blackbox.zig");
pub const timer = @import("timer.zig");
pub const stats = @import("stats.zig");
pub const suite = @import("suite.zig");

// Public re-exports
pub const blackBox = blackbox.blackBox;
pub const Timer = timer.Timer;
pub const BenchmarkStats = stats.BenchmarkStats;
pub const BenchmarkSuite = suite.BenchmarkSuite;
pub const BenchmarkOptions = suite.BenchmarkOptions;

test {
    _ = blackbox;
    _ = timer;
    _ = stats;
    _ = suite;
}
