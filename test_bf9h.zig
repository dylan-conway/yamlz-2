const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\---
        \\plain: a
        \\       b # end of scalar
        \\       c
        ;
    
    std.debug.print("Testing BF9H input:\n{s}\n\n", .{input});
    
    const result = parser.parse(input) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    _ = result;
    std.debug.print("Parse succeeded (should have failed!)\n", .{});
}