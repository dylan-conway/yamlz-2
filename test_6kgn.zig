const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\---
        \\a: &anchor
        \\b: *anchor
    ;
    
    const doc = try parser.parse(input);
    _ = doc;
    std.debug.print("6KGN test passed!\n", .{});
}