const std = @import("std");

pub const Timer = struct {
    start_ns: u64,

    pub fn start() Timer {
        return .{
            .start_ns = nowNs(),
        };
    }

    pub fn reset(self: *Timer) void {
        self.start_ns = nowNs();
    }

    pub fn readNs(self: *const Timer) u64 {
        const current = nowNs();
        return if (current >= self.start_ns) current - self.start_ns else 0;
    }

    pub fn nowNs() u64 {
        if (@import("builtin").os.tag == .windows) {
            var pc: std.os.windows.LARGE_INTEGER = undefined;
            _ = std.os.windows.ntdll.RtlQueryPerformanceCounter(&pc);
            return @as(u64, @intCast(@max(0, pc)));
        } else {
            var ts: std.posix.timespec = undefined;
            _ = std.posix.system.clock_gettime(.MONOTONIC, &ts);
            return @as(u64, @intCast(ts.sec)) * 1_000_000_000 + @as(u64, @intCast(ts.nsec));
        }
    }
};

test "timer elapsed" {
    var t = Timer.start();
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        sum += i;
    }
    _ = t.readNs();
}
