const std = @import("std");
// 3rd modules
const m = @import("metrics");
const zap = @import("zap");

const Metrics = struct {
    // counter to calculate how many hit to URL
    hits: m.Counter(u32),
};

pub const MetricsApp = struct {
    allocator: std.mem.Allocator,
    metrics: Metrics,

    pub fn init(allocator: std.mem.Allocator) MetricsApp {
        // initialize Metrics object as self.metrics
        return .{
            .allocator = allocator,
            .metrics = .{
                .hits = m.Counter(u32).init("hits", .{}, .{}),
            },
        };
    }

    fn metrics_handler(self: *MetricsApp, r: zap.Request) !void {
        self.metrics.hits.incr();

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
    var app = MetricsApp.init(std.testing.allocator);
    try std.testing.expectEqual(app.metrics.hits.impl.count, 0);
    app.metrics.hits.incr();
    try std.testing.expectEqual(app.metrics.hits.impl.count, 1);
}
