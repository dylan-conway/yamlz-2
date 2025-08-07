const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test with simple mappings
    const test1 = 
        \\-
        \\  a: b
        \\  c: d
        \\- e: f
    ;
    std.debug.print("Test 1 (no tags at all):\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Single entry mapping followed by item
    const test2 = 
        \\-
        \\  a: b
        \\- c: d
    ;
    std.debug.print("Test 2 (single entry mapping):\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}