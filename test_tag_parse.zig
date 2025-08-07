const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test just the problematic line
    const test1 = "b: !!str";
    std.debug.print("Test 1:\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Test with something after
    const test2 = 
        \\b: !!str
        \\c: d
    ;
    std.debug.print("Test 2:\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}