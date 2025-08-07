const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test each part separately
    const test1 = "- !!str";
    std.debug.print("Test 1:\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    const test2 = 
        \\-
        \\  !!null : a
        \\  b: !!str
    ;
    std.debug.print("Test 2:\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    const test3 = "- !!str : !!null";
    std.debug.print("Test 3:\n{s}\n", .{test3});
    _ = parser.parse(test3) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Now test the full thing
    const full_test = 
        \\- !!str
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- !!str : !!null
    ;
    std.debug.print("Full test:\n{s}\n", .{full_test});
    _ = parser.parse(full_test) catch |err| {
        std.debug.print("  Error: {}\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}