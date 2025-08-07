const std = @import("std");
const yaml = @import("./src/yaml_parser.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    const input = 
        \\---
        \\scalar
        \\%YAML 1.2
        \\
    ;
    
    std.debug.print("Testing XLQ9 input:\n{s}\n", .{input});
    
    const result = yaml.parse(allocator, input) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Try to render the output
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    try result.stringify(buffer.writer());
    std.debug.print("Parsed result: {s}\n", .{buffer.items});
}