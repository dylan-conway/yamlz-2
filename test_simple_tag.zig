const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test simple tag in mapping
    const test1 = "b: !!str";
    std.debug.print("Test 1:\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Test empty value with tag
    const test2 = "!!str :";
    std.debug.print("Test 2 (tag with colon):\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Test in a mapping
    const test3 = 
        \\a: b
        \\c: !!str
    ;
    std.debug.print("Test 3:\n{s}\n", .{test3});
    _ = parser.parse(test3) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}