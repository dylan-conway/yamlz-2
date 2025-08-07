const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "- { y: z }- invalid";
    
    std.debug.print("Testing P2EQ: '{s}'\n", .{input});
    
    const doc = parser.parse(input) catch |err| {
        std.debug.print("Parser correctly rejected input with error: {}\n", .{err});
        return;
    };
    _ = doc;
    
    std.debug.print("ERROR: Parser incorrectly accepted invalid input!\n", .{});
    std.debug.print("This test should fail - content after flow mapping close is not allowed\n", .{});
}