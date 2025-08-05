const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\key: "value"
    ;
    
    std.debug.print("Testing simple quoted:\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("ERROR: Got unexpected error: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("Success: Parsed correctly\n", .{});
}