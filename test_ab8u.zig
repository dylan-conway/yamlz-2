const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\- single multiline
        \\ - sequence entry
    ;
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("ERROR: Got unexpected error: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("Test passed!\n", .{});
}