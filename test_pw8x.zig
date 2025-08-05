const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\- &a
        \\- a
        \\-
        \\  &a : a
        \\  b: &b
        \\-
        \\  &c : &a
        \\-
        \\  ? &d
        \\-
        \\  ? &e
        \\  : &a
    ;
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("ERROR: Got unexpected error: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("Test passed!\n", .{});
}