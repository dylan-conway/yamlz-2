const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test if "- invalid" is valid YAML
    const input1 = "- invalid";
    std.debug.print("Testing: '{s}'\n", .{input1});
    const doc1 = parser.parse(input1) catch |err| {
        std.debug.print("  Failed with: {}\n", .{err});
        return;
    };
    _ = doc1;
    std.debug.print("  Parsed successfully\n", .{});
    
    // But the real issue is having it on the same line after other content
    const input2 = "- item1- invalid";  
    std.debug.print("\nTesting: '{s}'\n", .{input2});
    const doc2 = parser.parse(input2) catch |err| {
        std.debug.print("  Failed with: {}\n", .{err});
        return;
    };
    _ = doc2;
    std.debug.print("  Parsed successfully\n", .{});
}