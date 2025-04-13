const std = @import("std");
// 3rd modules
const m = @import("metrics");
const zap = @import("zap");

const Allocator = std.mem.Allocator;

const Metrics = struct {
    // counter to calculate how many hit to URL
    hits: m.Counter(u32),
};

pub const WebPackage = struct {
    allocator: Allocator,
    metrics: Metrics,

    pub fn init(allocator: Allocator) WebPackage {
        // initialize Metrics object as self.metrics
        return .{
            .allocator = allocator,
            .metrics = .{
                .hits = m.Counter(u32).init("hits", .{}, .{}),
            },
        };
    }

    pub fn getMetrics(self: *WebPackage, req: zap.Request) !void {
        // increase counter first when URL is hit
        self.metrics.hits.incr();

        // buffer for output
        var arr = std.ArrayList(u8).init(self.allocator);
        defer arr.deinit();
        try m.write(&self.metrics, arr.writer());

        // print buffer as http body
        req.sendBody(arr.items) catch return;
    }
};

fn not_found(req: zap.Request) !void {
    std.debug.print("not found handler", .{});

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
    try simpleRouter.handle_func("/metrics", &webPackage, &WebPackage.getMetrics);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(),
        .log = true,
    });
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}

test "simple test" {
    var webPackage = WebPackage.init(std.testing.allocator);
    try std.testing.expectEqual(webPackage.metrics.hits.impl.count, 0);
    webPackage.metrics.hits.incr();
    try std.testing.expectEqual(webPackage.metrics.hits.impl.count, 1);
}
