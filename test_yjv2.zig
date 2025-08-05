const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "[-]";
    
    std.debug.print("Testing YJV2 (dash in flow sequence):\n", .{});
    std.debug.print("Input: {s}\n", .{input});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}