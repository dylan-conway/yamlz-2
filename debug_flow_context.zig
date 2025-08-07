const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "- { y: z }- invalid";
    
    std.debug.print("Testing: '{s}'\n", .{input});
    
    // The parser when parsing "- { y: z }" at the block level should NOT be in flow context
    // The flow context should only be true INSIDE the { }
    
    const doc = parser.parse(input) catch |err| {
        std.debug.print("Parser correctly rejected with: {}\n", .{err});
        return;
    };
    _ = doc;
    
    std.debug.print("ERROR: Parser accepted invalid input!\n", .{});
}