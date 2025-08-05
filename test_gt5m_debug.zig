const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\- item1
        \\&node
        \\- item2
    ;
    
    std.debug.print("Testing GT5M (floating anchor):\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}