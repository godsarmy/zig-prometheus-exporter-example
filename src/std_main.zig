const std = @import("std");
// 3rd modules
const m = @import("metrics");

const Allocator = std.mem.Allocator;
const Metrics = struct {
    // counter to calculate how many hit to URL
    hits: m.Counter(u32),
};

pub const MetricsHandler = struct {
    allocator: Allocator,
    metrics: Metrics,

    pub fn init(allocator: Allocator) MetricsHandler {
        // initialize Metrics object as self.metrics
        return .{
            .allocator = allocator,
            .metrics = .{
                .hits = m.Counter(u32).init("hits", .{}, .{}),
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
            self.metrics.hits.incr();

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
    while (true) {
        try metricsHandler.handleConnection(try server.accept());
    }
}

test "simple test" {
    var metricsHandler = MetricsHandler.init(std.testing.allocator);
    try std.testing.expectEqual(metricsHandler.metrics.hits.impl.count, 0);
    metricsHandler.metrics.hits.incr();
    try std.testing.expectEqual(metricsHandler.metrics.hits.impl.count, 1);
}
