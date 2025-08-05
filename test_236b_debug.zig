const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\foo:
        \\  bar
        \\invalid
    ;
    
    std.debug.print("Testing 236B (invalid content after mapping):\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    std.debug.print("Input length: {}\n", .{input.len});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}