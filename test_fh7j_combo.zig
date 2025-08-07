const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test combinations
    const test1 = 
        \\- !!str
        \\-
        \\  !!null : a
    ;
    std.debug.print("Test 1 (first two items):\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    const test2 = 
        \\- !!str
        \\- !!null : a
    ;
    std.debug.print("Test 2 (without extra indent):\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    const test3 = 
        \\- !!str
        \\-
        \\  a: b
    ;
    std.debug.print("Test 3 (without tags in mapping):\n{s}\n", .{test3});
    _ = parser.parse(test3) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}