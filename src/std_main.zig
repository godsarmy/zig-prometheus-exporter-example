const std = @import("std");
// 3rd modules
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

pub const MetricsHandler = struct {
    allocator: std.mem.Allocator,
    metrics: Metrics,

    pub fn init(allocator: std.mem.Allocator) MetricsHandler {
        // initialize Metrics object as self.metrics
        return .{
            .allocator = allocator,
            .metrics = .{
                .hits = try Metrics.Hits.init(allocator, "hits", .{}, .{}),
                .accessed = Metrics.Accessed.init("accessed", .{}, .{}),
            },
        };
    }

    fn handleConnection(self: *MetricsHandler, conn: std.net.Server.Connection) !void {
        // instantialize http server from Tcp connection
        defer conn.stream.close();
        var buffer: [1024]u8 = undefined;
        var http_server = std.http.Server.init(conn, &buffer);
        var req = try http_server.receiveHead();

        const url = req.head.target;

        if (std.mem.startsWith(u8, url, "/metrics")) {
            // increase counter first when URL is hit
            const client = try std.fmt.allocPrint(self.allocator, "{any}", .{conn.address});
            defer self.allocator.free(client);

            const labels: HitLabel = .{ .client = client };
            try self.metrics.hits.incr(labels);
            self.metrics.accessed.set(@intCast(std.time.milliTimestamp()));

            // buffer for output
            var arr = std.ArrayList(u8).init(self.allocator);
            defer arr.deinit();
            try m.write(&self.metrics, arr.writer());

            // print buffer as http body
            try req.respond(arr.items, .{});
        } else {
            try req.respond("404 Not Found\n", .{ .status = std.http.Status.not_found });
        }
    }
};

pub fn main() !void {
    const address = try std.net.Address.parseIp4("127.0.0.1", 3000);

    std.debug.print("[std.http] Listening on 0.0.0.0:3000\n", .{});
    var server = try address.listen(std.net.Address.ListenOptions{});
    defer server.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var metricsHandler = MetricsHandler.init(allocator);
    defer metricsHandler.metrics.hits.deinit();

    while (true) {
        try metricsHandler.handleConnection(try server.accept());
    }
}

test "simple test" {
    var metricsHandler = MetricsHandler.init(std.testing.allocator);
    defer metricsHandler.metrics.hits.deinit();

    try std.testing.expectEqual(metricsHandler.metrics.accessed.impl.value, 0);

    const labels: HitLabel = .{ .client = "foo" };
    try metricsHandler.metrics.hits.incr(labels);
    metricsHandler.metrics.accessed.set(100);

    try std.testing.expectEqual(metricsHandler.metrics.hits.impl.values.get(labels).?.count, 1);
    try std.testing.expectEqual(metricsHandler.metrics.accessed.impl.value, 100);
}
