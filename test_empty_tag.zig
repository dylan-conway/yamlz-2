const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test empty scalar with tag
    const test1 = "!!str";
    std.debug.print("Test 1 (just tag):\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // In a sequence
    const test2 = "- !!str";
    std.debug.print("Test 2 (tag in sequence):\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // As a mapping key
    const test3 = "!!str : value";
    std.debug.print("Test 3 (tag as key):\n{s}\n", .{test3});
    _ = parser.parse(test3) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // As a mapping value  
    const test4 = "key: !!str";
    std.debug.print("Test 4 (tag as value):\n{s}\n", .{test4});
    _ = parser.parse(test4) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}