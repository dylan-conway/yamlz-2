const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\a: &anchor
        \\b: *anchor
    ;
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Test failed: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("Test passed!\n", .{});
}