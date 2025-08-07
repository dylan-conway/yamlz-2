const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // This works
    const test1 = 
        \\-
        \\  b: !!str
        \\- a
    ;
    std.debug.print("Test 1 (without !!null):\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Let's try with !!null
    const test2 = 
        \\-
        \\  !!null : a
        \\- b
    ;
    std.debug.print("Test 2 (with !!null and simple third item):\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Now with two mapping entries
    const test3 = 
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- c
    ;
    std.debug.print("Test 3 (two mapping entries with simple third):\n{s}\n", .{test3});
    _ = parser.parse(test3) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}