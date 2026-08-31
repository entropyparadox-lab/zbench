const std = @import("std");
const Allocator = std.mem.Allocator;
const timer_mod = @import("timer.zig");
const stats_mod = @import("stats.zig");
const blackbox_mod = @import("blackbox.zig");

pub const BenchmarkOptions = struct {
    warmup_ms: u64 = 50,
    sample_count: usize = 50,
    target_sample_time_ms: u64 = 10,
    bytes_per_op: ?u64 = null,
};

pub const SuiteRunOptions = struct {
    silent: bool = false,
};

pub const BenchmarkEntry = struct {
    name: []const u8,
    bench_fn: *const fn () void,
    options: BenchmarkOptions,
    stats: ?stats_mod.BenchmarkStats = null,
};

pub const BenchmarkSuite = struct {
    allocator: Allocator,
    entries: std.ArrayList(BenchmarkEntry),

    pub fn init(allocator: Allocator) BenchmarkSuite {
        return .{
            .allocator = allocator,
            .entries = .empty,
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        self.entries.deinit(self.allocator);
    }

    pub fn add(self: *BenchmarkSuite, name: []const u8, bench_fn: *const fn () void, options: BenchmarkOptions) !void {
        try self.entries.append(self.allocator, .{
            .name = name,
            .bench_fn = bench_fn,
            .options = options,
        });
    }

    pub fn run(self: *BenchmarkSuite) !void {
        try self.runWithOptions(.{ .silent = false });
    }

    pub fn runWithOptions(self: *BenchmarkSuite, run_opts: SuiteRunOptions) !void {
        if (!run_opts.silent) {
            std.debug.print("\n\x1b[1;36m========================================================================================================\x1b[0m\n", .{});
            std.debug.print("\x1b[1;37m  ⚡ zbench Statistical Microbenchmark Suite (Pure Zig 0.16.0+, Criterion-Grade) \x1b[0m\n", .{});
            std.debug.print("\x1b[1;36m========================================================================================================\x1b[0m\n\n", .{});
        }

        for (self.entries.items) |*entry| {
            try self.runSingle(entry);
        }

        if (!run_opts.silent) {
            self.printSummary();
        }
    }

    fn runSingle(self: *BenchmarkSuite, entry: *BenchmarkEntry) !void {
        // 1. Warmup & Calibration
        var iters_per_batch: u64 = 1;
        const warmup_deadline_ns = entry.options.warmup_ms * 1_000_000;
        var warmup_timer = timer_mod.Timer.start();

        while (warmup_timer.readNs() < warmup_deadline_ns) {
            var i: u64 = 0;
            while (i < iters_per_batch) : (i += 1) {
                entry.bench_fn();
            }
            if (iters_per_batch < 10_000_000) {
                iters_per_batch *= 2;
            }
        }

        // Calibrate iterations to fit target_sample_time_ms
        const target_sample_ns = entry.options.target_sample_time_ms * 1_000_000;
        var calib_timer = timer_mod.Timer.start();
        var c: u64 = 0;
        while (c < iters_per_batch) : (c += 1) {
            entry.bench_fn();
        }
        const calib_elapsed = calib_timer.readNs();
        if (calib_elapsed > 0) {
            const scaled_iters = (@as(f64, @floatFromInt(target_sample_ns)) / @as(f64, @floatFromInt(calib_elapsed))) * @as(f64, @floatFromInt(iters_per_batch));
            iters_per_batch = @max(1, @as(u64, @intFromFloat(scaled_iters)));
        }

        // 2. Sample Collection
        const samples = try self.allocator.alloc(f64, entry.options.sample_count);
        defer self.allocator.free(samples);

        for (samples) |*s| {
            var sample_timer = timer_mod.Timer.start();
            var i: u64 = 0;
            while (i < iters_per_batch) : (i += 1) {
                entry.bench_fn();
            }
            const elapsed_ns = sample_timer.readNs();
            s.* = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iters_per_batch));
        }

        // 3. Statistical Analysis
        entry.stats = try stats_mod.BenchmarkStats.calculate(
            self.allocator,
            samples,
            iters_per_batch,
            entry.options.bytes_per_op,
        );
    }

    fn printSummary(self: *const BenchmarkSuite) void {
        std.debug.print("\x1b[1;37m{s:<28} | {s:>14} | {s:>16} | {s:>14} | {s:>10} | {s}\x1b[0m\n", .{
            "Benchmark",
            "Throughput",
            "Latency (Mean±σ)",
            "p50 (Median)",
            "p99",
            "Distribution",
        });
        std.debug.print("-----------------------------+----------------+------------------+----------------+------------+-------------------\n", .{});

        for (self.entries.items) |entry| {
            if (entry.stats) |st| {
                var tp_buf: [32]u8 = undefined;
                const tp_str = if (st.mb_per_sec) |mb|
                    std.fmt.bufPrint(&tp_buf, "{d:.2} MB/s", .{mb}) catch "-"
                else if (st.ops_per_sec >= 1_000_000.0)
                    std.fmt.bufPrint(&tp_buf, "{d:.2} M ops/s", .{st.ops_per_sec / 1_000_000.0}) catch "-"
                else if (st.ops_per_sec >= 1_000.0)
                    std.fmt.bufPrint(&tp_buf, "{d:.2} K ops/s", .{st.ops_per_sec / 1_000.0}) catch "-"
                else
                    std.fmt.bufPrint(&tp_buf, "{d:.1} ops/s", .{st.ops_per_sec}) catch "-";

                var lat_buf: [32]u8 = undefined;
                const lat_str = formatDuration(&lat_buf, st.mean_ns, st.stddev_ns);

                var p50_buf: [32]u8 = undefined;
                const p50_str = formatSingleDuration(&p50_buf, st.median_ns);

                var p99_buf: [32]u8 = undefined;
                const p99_str = formatSingleDuration(&p99_buf, st.p99_ns);

                const spark = st.sparkline[0..st.sparkline_len];

                std.debug.print("\x1b[1;32m{s:<28}\x1b[0m | \x1b[33m{s:>14}\x1b[0m | {s:>16} | {s:>14} | {s:>10} | \x1b[36m{s}\x1b[0m\n", .{
                    entry.name,
                    tp_str,
                    lat_str,
                    p50_str,
                    p99_str,
                    spark,
                });
            }
        }
        std.debug.print("\n", .{});
    }

    fn formatDuration(buf: []u8, mean_ns: f64, stddev_ns: f64) []const u8 {
        if (mean_ns < 1000.0) {
            return std.fmt.bufPrint(buf, "{d:.1}±{d:.1} ns", .{ mean_ns, stddev_ns }) catch "-";
        } else if (mean_ns < 1_000_000.0) {
            return std.fmt.bufPrint(buf, "{d:.2}±{d:.2} µs", .{ mean_ns / 1000.0, stddev_ns / 1000.0 }) catch "-";
        } else {
            return std.fmt.bufPrint(buf, "{d:.2}±{d:.2} ms", .{ mean_ns / 1_000_000.0, stddev_ns / 1_000_000.0 }) catch "-";
        }
    }

    fn formatSingleDuration(buf: []u8, val_ns: f64) []const u8 {
        if (val_ns < 1000.0) {
            return std.fmt.bufPrint(buf, "{d:.1} ns", .{val_ns}) catch "-";
        } else if (val_ns < 1_000_000.0) {
            return std.fmt.bufPrint(buf, "{d:.2} µs", .{val_ns / 1000.0}) catch "-";
        } else {
            return std.fmt.bufPrint(buf, "{d:.2} ms", .{val_ns / 1000.0}) catch "-";
        }
    }
};

test "suite add and run" {
    const allocator = std.testing.allocator;
    var suite = BenchmarkSuite.init(allocator);
    defer suite.deinit();

    const dummy = struct {
        fn bench() void {
            var x: u64 = 0;
            var i: usize = 0;
            while (i < 100) : (i += 1) {
                x += i;
            }
            _ = blackbox_mod.blackBox(x);
        }
    };

    try suite.add("dummy_loop", dummy.bench, .{ .sample_count = 10, .warmup_ms = 10 });
    try suite.runWithOptions(.{ .silent = true });
}
