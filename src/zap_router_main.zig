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

pub const WebPackage = struct {
    allocator: std.mem.Allocator,
    metrics: Metrics,

    pub fn init(allocator: std.mem.Allocator) WebPackage {
        // initialize Metrics object as self.metrics
        return .{
            .allocator = allocator,
            .metrics = .{
                .hits = try Metrics.Hits.init(allocator, "hits", .{}, .{}),
                .accessed = Metrics.Accessed.init("accessed", .{}, .{}),
            },
        };
    }

    pub fn getMetrics(self: *WebPackage, req: zap.Request) !void {
        // increase counter first when URL is hit
        const addr_info_s = zap.fio.http_peer_addr(req.h);
        const client = info2addr(addr_info_s);

        const labels: HitLabel = .{ .client = client };
        try self.metrics.hits.incr(labels);
        self.metrics.accessed.set(@intCast(std.time.milliTimestamp()));

        // buffer for output
        var arr = std.ArrayList(u8).init(self.allocator);
        defer arr.deinit();
        try m.write(&self.metrics, arr.writer());

        // print buffer as http body
        req.sendBody(arr.items) catch return;
    }
};

fn not_found(req: zap.Request) !void {
    try req.sendBody("Not found");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var simpleRouter = zap.Router.init(allocator, .{
        .not_found = not_found,
    });
    defer simpleRouter.deinit();

    var webPackage = WebPackage.init(allocator);
    defer webPackage.metrics.hits.deinit();

    try simpleRouter.handle_func("/metrics", &webPackage, &WebPackage.getMetrics);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(),
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
    var webPackage = WebPackage.init(std.testing.allocator);
    defer webPackage.metrics.hits.deinit();

    try std.testing.expectEqual(webPackage.metrics.accessed.impl.value, 0);

    const labels: HitLabel = .{ .client = "foo" };
    try webPackage.metrics.hits.incr(labels);
    webPackage.metrics.accessed.set(100);

    try std.testing.expectEqual(webPackage.metrics.hits.impl.values.get(labels).?.count, 1);
    try std.testing.expectEqual(webPackage.metrics.accessed.impl.value, 100);
}
