const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "---\n- [-, -]";
    
    std.debug.print("Testing G5U8 (multiple dashes in flow):\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}