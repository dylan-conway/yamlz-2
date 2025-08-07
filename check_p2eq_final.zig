const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test the P2EQ case
    const p2eq_input = "- { y: z }- invalid";
    std.debug.print("Testing P2EQ: '{s}'\n", .{p2eq_input});
    
    const result = parser.parse(p2eq_input) catch |err| {
        std.debug.print("✓ Correctly rejected with error: {}\n", .{err});
        return;
    };
    _ = result;
    
    std.debug.print("✗ ERROR: Parser incorrectly accepted invalid input\n", .{});
    std.process.exit(1);
}