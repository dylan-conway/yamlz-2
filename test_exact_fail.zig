const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // The exact failing case
    const test1 = 
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- !!str : !!null
    ;
    std.debug.print("Test 1 (exact failing case):\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}