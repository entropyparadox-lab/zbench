# zbench 📊

[![Zig Version](https://img.shields.io/badge/Zig-0.16.0%2B-orange.svg)](https://ziglang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Zero C Dependencies](https://img.shields.io/badge/Zero--C-Pure%20Zig-brightgreen.svg)]()
[![Statistical Analysis](https://img.shields.io/badge/Criterion.rs--Grade-Tukey%20Fences-purple.svg)]()

**Criterion.rs-Grade Statistical Microbenchmarking & Performance Profiling Toolkit for Zig (v0.16.0+)**

`zbench` is an ergonomic, zero-C-dependency benchmarking framework for pure Zig. It brings statistical rigour, compiler-elision-proof `blackBox` fences, Tukey's outlier filtering, sub-nanosecond monotonic timing, and rich terminal ANSI sparkline reporting to Zig projects.

---

## Example Output

```text
========================================================================================================
  ⚡ zbench Statistical Microbenchmark Suite (Pure Zig 0.16.0+, Criterion-Grade) 
========================================================================================================

Benchmark                    |     Throughput | Latency (Mean±σ) |   p50 (Median) |        p99 | Distribution
-----------------------------+----------------+------------------+----------------+------------+-------------------
Fibonacci(20)                |  87.64 K ops/s |  11.41±0.37 µs |      11.33 µs |  12.14 µs | ▂▇█ ▇ ▃▅▂▆▄▂▃▂▃ 
SHA256 (1KB Buffer)          |   1991.62 MB/s |   490.3±10.4 ns |       486.8 ns |   527.3 ns |   ▂▃▂    ▇▇   ▄▃
QuickSort (256 integers)     |   1.69 M ops/s |   593.1±37.5 ns |       581.2 ns |   722.3 ns |      ▃▂▃   ▂▂▂▂
```

---

## Key Features

- 🛡️ **Compiler Optimization Barrier (`zbench.blackBox`)**: Guarantees benchmarked calculations and allocations are not optimized away by LLVM/Zig compiler in `ReleaseFast`.
- ⏱️ **Sub-Nanosecond OS Monotonic Timer**: Native POSIX `CLOCK_MONOTONIC` timing with zero runtime overhead.
- 🎯 **Automated Warmup & Batch Calibration**: Automatically calculates the optimal iteration count to measure short (<100ns) and long functions accurately.
- 📐 **Rigorous Statistical Analysis**:
  - **Tukey's Fences** for mild and extreme outlier detection.
  - **Percentiles**: p50 (Median), p75, p90, p95, p99.
  - **Throughput**: Computes operations/sec and MB/s or GB/s automatically when byte size is provided.
- 📊 **Terminal ANSI Sparklines**: Unicode 8-level distribution plots (` ▂▃▄▅▆▇█`) printed directly in your terminal.
- 📦 **Pure Zig 0.16.0+**: Zero C dependencies, instant compilation, fully cross-compilable.

---

## Installation (`build.zig.zon`)

Add `zbench` to your `build.zig.zon`:

```bash
zig fetch --save https://github.com/entropyparadox-lab/zbench/archive/refs/tags/v1.0.0.tar.gz
```

In your `build.zig`:

```zig
const zbench_dep = b.dependency("zbench", .{
    .target = target,
    .optimize = .ReleaseFast,
});
exe.root_module.addImport("zbench", zbench_dep.module("zbench"));
```

---

## Quickstart

```zig
const std = @import("std");
const zbench = @import("zbench");

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

    try suite.add("QuickSort (256 integers)", benchSorting, .{
        .warmup_ms = 100,
        .sample_count = 50,
    });

    try suite.run();
}
```

---

## License

MIT License (c) 2026 Entropy Paradox Lab / Charles Choi
