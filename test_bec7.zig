const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\%YAML 1.3 # Attempt parsing
        \\          # with a warning
        \\---
        \\"foo"
        \\
    ;
    
    const result = parser.parse(input);
    
    if (result) |_| {
        std.debug.print("Parser accepted YAML 1.3 (BEC7 expects this to succeed with warning)\n", .{});
        std.process.exit(0);
    } else |err| {
        std.debug.print("Parser rejected with error: {} (BEC7 expects success with warning)\n", .{err});
        std.process.exit(1);
    }
}