const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\%YAML 1.2
        \\%YAML 1.2
        \\---
        \\
    ;
    
    const result = parser.parse(input);
    
    if (result) |_| {
        std.debug.print("Parser accepted the input (should have rejected it!)\n", .{});
        std.process.exit(1);
    } else |err| {
        std.debug.print("Parser correctly rejected with error: {}\n", .{err});
        std.process.exit(0);
    }
}