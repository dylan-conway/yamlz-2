const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\- item1
        \\- item2
    ;
    
    std.debug.print("Testing simple sequence:\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("ERROR: Got unexpected error: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("Success: Parsed correctly\n", .{});
}