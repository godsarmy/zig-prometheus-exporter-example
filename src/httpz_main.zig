const std = @import("std");
// 3rd modules
const httpz = @import("httpz");
const m = @import("metrics");

const Metrics = struct {
    // counter to calculate how many hit to URL
    hits: m.Counter(u32),
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
            .hits = m.Counter(u32).init("hits", .{}, .{}),
        },
    };

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

fn getMetrics(app: *App, _: *httpz.Request, res: *httpz.Response) !void {
    app.metrics.hits.incr();
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
    var app = App{
        .allocator = std.testing.allocator,
        .metrics = .{
            .hits = m.Counter(u32).init("hits", .{}, .{}),
        },
    };
    try std.testing.expectEqual(app.metrics.hits.impl.count, 0);
    app.metrics.hits.incr();
    try std.testing.expectEqual(app.metrics.hits.impl.count, 1);
}
