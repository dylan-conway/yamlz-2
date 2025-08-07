const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test the second item which is causing the issue
    const yaml_content = 
        \\-
        \\  !!null : a
        \\  b: !!str
    ;
    
    std.debug.print("Testing problematic sequence item:\n{s}\n", .{yaml_content});
    
    const doc = parser.parse(yaml_content) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    _ = doc;
    std.debug.print("Parse successful!\n", .{});
}