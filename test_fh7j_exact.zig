const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test with exactly 2 mapping entries
    const test1 = 
        \\- !!str
        \\-
        \\  !!null : a
        \\  b: !!str
    ;
    std.debug.print("Test 1 (with 2 mapping entries):\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Now without the first item
    const test2 = 
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- !!str : !!null
    ;
    std.debug.print("Test 2 (second and third items):\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}