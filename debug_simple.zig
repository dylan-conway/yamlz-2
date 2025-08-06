const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "[23\n]: 42";
    
    std.debug.print("Testing with parse() function (what test runner uses):\n", .{});
    
    const result = parser.parse(input);
    if (result) |doc| {
        std.debug.print("SUCCESS: Parse succeeded (this should fail!)\n", .{});
        if (doc.root) |root| {
            std.debug.print("Root type: {}\n", .{root.type});
        }
    } else |err| {
        std.debug.print("ERROR: Parse failed with error: {}\n", .{err});
    }
}