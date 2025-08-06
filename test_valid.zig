const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "[23]: 42";
    
    std.debug.print("Input: {s}\n", .{input});
    
    const result = parser.parse(input);
    if (result) |doc| {
        std.debug.print("Parse succeeded (this should work)!\n", .{});
        if (doc.root) |root| {
            std.debug.print("Root type: {}\n", .{root.type});
        }
    } else |err| {
        std.debug.print("Parse failed with error: {} (this shouldn't fail)\n", .{err});
    }
}