const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\foo:
        \\  bar
        \\invalid
    ;
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}