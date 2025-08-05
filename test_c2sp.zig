const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "[23\n]: 42";
    
    std.debug.print("Testing C2SP (flow mapping key on two lines):\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}