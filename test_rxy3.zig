const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\---
        \\'
        \\...
        \\'
    ;

    std.debug.print("Testing RXY3 input:\n{s}\n", .{input});
    
    const result = parser.parse(input);
    
    if (result) |_| {
        std.debug.print("Parser accepted the input (FAIL - should reject)\n", .{});
    } else |err| {
        std.debug.print("Parser rejected with error: {}\n", .{err});
    }
}