const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\---
        \\a: &anchor
        \\b: *anchor
    ;
    
    std.debug.print("Testing 6KGN (anchor/alias):\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("ERROR: Got unexpected error: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("Success: Parsed correctly\n", .{});
}