const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Root module for library
    const zbench_mod = b.addModule("zbench", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 2. Unit & Integration Tests using root_module
    const unit_tests = b.addTest(.{
        .root_module = zbench_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run zbench unit & integration tests");
    test_step.dependOn(&run_unit_tests.step);

    // 3. Example Benchmark Executable (ReleaseFast by default)
    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    example_mod.addImport("zbench", zbench_mod);

    const example_exe = b.addExecutable(.{
        .name = "zbench-example",
        .root_module = example_mod,
    });

    const run_example = b.addRunArtifact(example_exe);
    const example_step = b.step("run-example", "Run zbench example benchmarks");
    example_step.dependOn(&run_example.step);
}
