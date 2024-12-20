const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

/// libgeos notice handler. Is called by C fn shimNotice().
export fn noticeHandler(msg: [*:0]u8) void {
    std.log.info("libgeos: {s}", .{msg});
    defer std.c.free(msg);
}

/// libgeos log and exit handler. Is called by C fn shimError().
/// If is_test, then warns but don't exit().
export fn errorHandler(msg: [*:0]const u8) void {
    if (!builtin.is_test) {
        std.log.err("libgeos: {s}", .{msg});
        // std.os.exit(1);
    } else {
        // just warn and dont exit, otherwise tests will fail
        std.log.warn("libgeos: {s}", .{msg});
    }
}
