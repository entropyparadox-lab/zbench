# Contributing to zbench 📊

Thank you for contributing to `zbench`! To maintain the highest statistical accuracy and reliability, we follow strict guidelines.

---

## 1. Compiler Versioning & Branch Strategy

* **`main` (Protected)**: Targets **Official Stable Zig (`0.16.x`)**. All production releases (`vX.Y.Z`) are cut exclusively from `main`.
* **`zig-master`**: Tracks upstream `ziglang/zig` nightly builds.
* **`feat/<name>` / `fix/<name>`**: Branch off `main` for stable changes.

---

## 2. Strict Quality & Verification Gate

1. **100% Tested & Verified**: Every PR must include reproducible test coverage (`zig build test`).
2. **Optimization Fence**: `blackBox` must prevent dead code elimination without adding CPU instruction overhead.
3. **Statistical Invariant**: Outlier calculations must follow Tukey's Fences formula ($Q1 - 1.5 \times IQR$, $Q3 + 1.5 \times IQR$).

---

## 3. Fast Local Development & Git Hooks

Install local pre-commit hooks:
```bash
./scripts/setup-hooks.sh
```

Before opening a PR, run full local verification:
```bash
# 1. Format code
zig fmt src/ examples/ build.zig

# 2. Run unit tests
zig build test

# 3. Run benchmarks
zig build run-example
```

---

## 4. Immutable Release & SemVer Policy

* **Semantic Versioning (SemVer 2.0.0)**:
  * `PATCH (1.0.X)`: Bug fixes, statistical corrections, documentation.
  * `MINOR (1.X.0)`: New statistical models, reporters, exporters.
  * `MAJOR (X.0.0)`: Breaking API changes.
