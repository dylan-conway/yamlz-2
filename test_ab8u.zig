const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\- single multiline
        \\ - sequence entry
        \\
    ;
    
    std.debug.print("Testing AB8U (should pass):\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    const result = parser.parseStream(input);
    
    if (result) |_| {
        std.debug.print("Result: SUCCESS\n", .{});
    } else |err| {
        std.debug.print("Result: ERROR - {} (this is wrong - should have passed)\n", .{err});
    }
}