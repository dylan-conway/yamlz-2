const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const yaml_input = 
        \\---
        \\key: value
        \\... invalid
        \\
    ;
    
    std.debug.print("Testing 3HFZ: Document end marker with invalid content after\n", .{});
    std.debug.print("Input:\n{s}\n", .{yaml_input});
    
    const doc = parser.parse(yaml_input) catch |err| {
        std.debug.print("✓ Parser correctly rejected with error: {}\n", .{err});
        return;
    };
    
    _ = doc;
    std.debug.print("✗ Parser incorrectly accepted the input\n", .{});
}