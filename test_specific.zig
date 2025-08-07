const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // The problematic transition seems to be the mapping with two entries followed by another sequence item
    
    // Test without the third item
    const test1 = 
        \\-
        \\  !!null : a
        \\  b: !!str
    ;
    std.debug.print("Test 1 (mapping with tags, no third item):\n{s}\n", .{test1});
    _ = parser.parse(test1) catch |err| {
        std.debug.print("  Error: {}\n\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Add third item WITHOUT tag
    const test2 = 
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- c: d
    ;
    std.debug.print("Test 2 (third item is plain mapping):\n{s}\n", .{test2});
    _ = parser.parse(test2) catch |err| {
        std.debug.print("  Error: {}\n\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // Third item WITH tag on key only
    const test3 = 
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- !!str : d
    ;
    std.debug.print("Test 3 (third item has tag on key):\n{s}\n", .{test3});
    _ = parser.parse(test3) catch |err| {
        std.debug.print("  Error: {}\n\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
    
    // The actual failing case
    const test4 = 
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- !!str : !!null
    ;
    std.debug.print("Test 4 (actual failing case):\n{s}\n", .{test4});
    _ = parser.parse(test4) catch |err| {
        std.debug.print("  Error: {}\n\n", .{err});
        return;
    };
    std.debug.print("  Success\n\n", .{});
}