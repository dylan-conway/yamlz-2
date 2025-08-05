const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\["a", "b", "c"]
    ;
    
    std.debug.print("Testing flow quoted:\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("ERROR: Got unexpected error: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("Success: Parsed correctly\n", .{});
}