const std = @import("std");
const Allocator = std.mem.Allocator;

pub const BenchmarkStats = struct {
    sample_count: usize,
    iterations_per_sample: u64,
    min_ns: f64,
    max_ns: f64,
    mean_ns: f64,
    stddev_ns: f64,
    median_ns: f64,
    p75_ns: f64,
    p90_ns: f64,
    p95_ns: f64,
    p99_ns: f64,
    iqr_ns: f64,
    outliers_mild: usize,
    outliers_extreme: usize,
    ops_per_sec: f64,
    mb_per_sec: ?f64 = null,
    sparkline: [64]u8 = undefined,
    sparkline_len: usize = 0,

    pub fn calculate(allocator: Allocator, raw_samples_ns: []const f64, iterations_per_sample: u64, bytes_per_op: ?u64) !BenchmarkStats {
        if (raw_samples_ns.len == 0) return error.EmptySamples;

        // Copy and sort samples
        const sorted = try allocator.alloc(f64, raw_samples_ns.len);
        defer allocator.free(sorted);
        @memcpy(sorted, raw_samples_ns);
        std.mem.sort(f64, sorted, {}, comptime std.sort.asc(f64));

        const n = sorted.len;
        const n_f = @as(f64, @floatFromInt(n));

        var sum: f64 = 0;
        for (sorted) |s| sum += s;
        const mean = sum / n_f;

        var var_sum: f64 = 0;
        for (sorted) |s| {
            const diff = s - mean;
            var_sum += diff * diff;
        }
        const stddev = @sqrt(var_sum / n_f);

        const min_val = sorted[0];
        const max_val = sorted[n - 1];

        const p25 = percentileSorted(sorted, 0.25);
        const p50 = percentileSorted(sorted, 0.50);
        const p75 = percentileSorted(sorted, 0.75);
        const p90 = percentileSorted(sorted, 0.90);
        const p95 = percentileSorted(sorted, 0.95);
        const p99 = percentileSorted(sorted, 0.99);

        const iqr = p75 - p25;
        const lower_mild = @max(0.0, p25 - 1.5 * iqr);
        const upper_mild = p75 + 1.5 * iqr;
        const lower_extreme = @max(0.0, p25 - 3.0 * iqr);
        const upper_extreme = p75 + 3.0 * iqr;

        var mild_count: usize = 0;
        var extreme_count: usize = 0;

        for (sorted) |s| {
            if (s < lower_extreme or s > upper_extreme) {
                extreme_count += 1;
            } else if (s < lower_mild or s > upper_mild) {
                mild_count += 1;
            }
        }

        const ops_per_sec = if (mean > 0) 1_000_000_000.0 / mean else 0.0;
        const mb_per_sec: ?f64 = if (bytes_per_op) |b|
            (@as(f64, @floatFromInt(b)) * ops_per_sec) / (1024.0 * 1024.0)
        else
            null;

        var stats = BenchmarkStats{
            .sample_count = n,
            .iterations_per_sample = iterations_per_sample,
            .min_ns = min_val,
            .max_ns = max_val,
            .mean_ns = mean,
            .stddev_ns = stddev,
            .median_ns = p50,
            .p75_ns = p75,
            .p90_ns = p90,
            .p95_ns = p95,
            .p99_ns = p99,
            .iqr_ns = iqr,
            .outliers_mild = mild_count,
            .outliers_extreme = extreme_count,
            .ops_per_sec = ops_per_sec,
            .mb_per_sec = mb_per_sec,
        };

        generateSparkline(&stats, raw_samples_ns);
        return stats;
    }

    fn percentileSorted(sorted: []const f64, p: f64) f64 {
        const n = sorted.len;
        if (n == 1) return sorted[0];
        const idx = p * @as(f64, @floatFromInt(n - 1));
        const lower = @as(usize, @intFromFloat(idx));
        const frac = idx - @as(f64, @floatFromInt(lower));
        if (lower + 1 < n) {
            return sorted[lower] + frac * (sorted[lower + 1] - sorted[lower]);
        } else {
            return sorted[lower];
        }
    }

    fn generateSparkline(stats: *BenchmarkStats, samples: []const f64) void {
        const sparks = [_][]const u8{ " ", "▂", "▃", "▄", "▅", "▆", "▇", "█" };
        const num_bins: usize = @min(16, samples.len);
        if (num_bins == 0) return;

        const range = stats.max_ns - stats.min_ns;
        var pos: usize = 0;

        const step = @as(f64, @floatFromInt(samples.len)) / @as(f64, @floatFromInt(num_bins));

        var bin: usize = 0;
        while (bin < num_bins) : (bin += 1) {
            const idx = @min(samples.len - 1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(bin)) * step)));
            const val = samples[idx];
            const norm = if (range > 0) (val - stats.min_ns) / range else 0.0;
            const spark_idx = @min(sparks.len - 1, @as(usize, @intFromFloat(norm * 7.99)));
            const glyph = sparks[spark_idx];
            if (pos + glyph.len <= stats.sparkline.len) {
                @memcpy(stats.sparkline[pos .. pos + glyph.len], glyph);
                pos += glyph.len;
            }
        }
        stats.sparkline_len = pos;
    }
};

test "stats calculation & percentiles" {
    const allocator = std.testing.allocator;
    const samples = [_]f64{ 10.0, 12.0, 11.0, 10.5, 13.0, 10.2, 10.8, 11.2, 50.0 };

    const stats = try BenchmarkStats.calculate(allocator, &samples, 1000, null);
    try std.testing.expect(stats.median_ns >= 10.0 and stats.median_ns <= 13.0);
    try std.testing.expect(stats.outliers_extreme >= 1 or stats.outliers_mild >= 1);
}
