const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input =
        \\key:
        \\  ok: 1
        \\ wrong: 2
        \\
    ;
    
    std.debug.print("Testing DMG6 input:\n{s}\n", .{input});
    
    const result = parser.parse(input) catch |err| {
        std.debug.print("Got error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parsing succeeded (should have failed!)\n", .{});
    
    // Print the parsed structure
    if (result.root) |root| {
        std.debug.print("Root type: {}\n", .{root.type});
    }
}