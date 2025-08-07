const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const yaml_content = 
        \\- !!str
        \\-
        \\  !!null : a
        \\  b: !!str
        \\- !!str : !!null
    ;
    
    std.debug.print("Testing FH7J:\n{s}\n", .{yaml_content});
    
    const doc = parser.parse(yaml_content) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    _ = doc;
    std.debug.print("Parse successful!\n", .{});
}