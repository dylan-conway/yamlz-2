const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input =
        \\a:
        \\  b:
        \\    c: d
        \\  e:
        \\    f: g
        \\h: i
        \\
    ;
    
    std.debug.print("Testing 9FMG input:\n{s}\n", .{input});
    
    const result = parser.parse(input) catch |err| {
        std.debug.print("Got error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parsing succeeded!\n", .{});
    
    // Print the parsed structure
    if (result.root) |root| {
        std.debug.print("Root type: {}\n", .{root.type});
    }
}