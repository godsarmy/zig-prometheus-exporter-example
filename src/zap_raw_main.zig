const std = @import("std");
// 3rd modules
const m = @import("metrics");
const zap = @import("zap");

const HitLabel = struct { client: []const u8 };
const Metrics = struct {
    const Hits = m.CounterVec(u64, HitLabel);
    const Accessed = m.Gauge(u64);

    // counter to calculate how many hit to URL
    hits: Hits,
    // gauge for latest accessed timestamp in epoch
    accessed: Accessed,
};

pub fn info2addr(info_s: zap.fio.fio_str_info_s) []const u8 {
    if (info_s.data == 0)
        return "";
    return info_s.data[0..info_s.len];
}

pub const MetricsApp = struct {
    allocator: std.mem.Allocator,
    metrics: Metrics,

    pub fn init(allocator: std.mem.Allocator) MetricsApp {
        // initialize Metrics object as self.metrics
        return .{
            .allocator = allocator,
            .metrics = .{
                .hits = try Metrics.Hits.init(allocator, "hits", .{}, .{}),
                .accessed = Metrics.Accessed.init("accessed", .{}, .{}),
            },
        };
    }

    fn metrics_handler(self: *MetricsApp, r: zap.Request) !void {
        const addr_info_s = zap.fio.http_peer_addr(r.h);
        const client = info2addr(addr_info_s);

        const labels: HitLabel = .{ .client = client };
        try self.metrics.hits.incr(labels);
        self.metrics.accessed.set(@intCast(std.time.milliTimestamp()));

        // buffer for output
        var arr = std.ArrayList(u8).init(self.allocator);
        defer arr.deinit();
        try m.write(&self.metrics, arr.writer());
        try r.sendBody(arr.items);
    }
};

var app: MetricsApp = undefined;

fn dispatch_routes(r: zap.Request) !void {
    // dispatch
    if (r.path) |the_path| {
        if (std.mem.eql(u8, the_path, "/metrics")) {
            try app.metrics_handler(r);
            return;
        } else {
            try r.sendBody("Unknown route");
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();
    app = MetricsApp.init(allocator);
    defer app.metrics.hits.deinit();

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = dispatch_routes,
        .log = true,
    });
    std.debug.print("[zap] Listening on 0.0.0.0:3000\n", .{});
    try listener.listen();

    // start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}

test "simple test" {
    app = MetricsApp.init(std.testing.allocator);
    defer app.metrics.hits.deinit();

    try std.testing.expectEqual(app.metrics.accessed.impl.value, 0);

    const labels: HitLabel = .{ .client = "foo" };
    try app.metrics.hits.incr(labels);
    app.metrics.accessed.set(100);

    try std.testing.expectEqual(app.metrics.hits.impl.values.get(labels).?.count, 1);
    try std.testing.expectEqual(app.metrics.accessed.impl.value, 100);
}
