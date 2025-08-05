const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // First test: anchor with value
    const input1 = 
        \\a: &anchor value
        \\b: *anchor
    ;
    
    const doc1 = parser.parse(input1) catch |e| {
        std.debug.print("Test 1 failed: {}\n", .{e});
        return;
    };
    _ = doc1;
    std.debug.print("Test 1 passed: anchor with value\n", .{});
    
    // Second test: anchor without value (null)
    const input2 = 
        \\a: &anchor
        \\b: *anchor
    ;
    
    const doc2 = parser.parse(input2) catch |e| {
        std.debug.print("Test 2 failed: {}\n", .{e});
        return;
    };
    _ = doc2;
    std.debug.print("Test 2 passed: anchor without value\n", .{});
}