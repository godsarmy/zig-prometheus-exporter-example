const std = @import("std");
// 3rd modules
const httpz = @import("httpz");
const m = @import("metrics");

const HitLabel = struct { client: []const u8 };
const Metrics = struct {
    const Hits = m.CounterVec(u64, HitLabel);
    const Accessed = m.Gauge(u64);

    // counter to calculate how many hit to URL
    hits: Hits,
    // gauge for latest accessed timestamp in epoch
    accessed: Accessed,
};

const App = struct {
    allocator: std.mem.Allocator,
    metrics: Metrics,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = App{
        .allocator = allocator,
        .metrics = .{
            .hits = try Metrics.Hits.init(allocator, "hits", .{}, .{}),
            .accessed = Metrics.Accessed.init("accessed", .{}, .{}),
        },
    };
    defer app.metrics.hits.deinit();

    var server = try httpz.Server(*App).init(allocator, .{ .port = 3000 }, &app);
    defer {
        // clean shutdown, finishes serving any live request
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.get("/metrics", getMetrics, .{});

    // blocks
    std.debug.print("[http.zig] Listening on 0.0.0.0:3000\n", .{});
    try server.listen();
}

fn getMetrics(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const client = try std.fmt.allocPrint(app.allocator, "{any}", .{req.address});
    defer app.allocator.free(client);

    const labels: HitLabel = .{ .client = client };
    try app.metrics.hits.incr(labels);
    app.metrics.accessed.set(@intCast(std.time.milliTimestamp()));
    res.status = 200;

    var arr = std.ArrayList(u8).init(app.allocator);
    defer arr.deinit();
    try m.write(&app.metrics, arr.writer());

    std.debug.print("{s}\n", .{arr.items});
    // res.body = std.fmt.allocPrint(res.arena, arr.items, .{});
    res.body = arr.items;
    return res.write();
}

test "simple test" {
    const test_allocator = std.testing.allocator;
    var app = App{
        .allocator = test_allocator,
        .metrics = .{
            .hits = try Metrics.Hits.init(test_allocator, "hits", .{}, .{}),
            .accessed = Metrics.Accessed.init("accessed", .{}, .{}),
        },
    };
    defer app.metrics.hits.deinit();

    try std.testing.expectEqual(app.metrics.accessed.impl.value, 0);

    const labels: HitLabel = .{ .client = "foo" };
    try app.metrics.hits.incr(labels);
    app.metrics.accessed.set(100);

    try std.testing.expectEqual(app.metrics.hits.impl.values.get(labels).?.count, 1);
    try std.testing.expectEqual(app.metrics.accessed.impl.value, 100);
}
