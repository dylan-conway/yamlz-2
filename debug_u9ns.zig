const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test the actual U9NS case
    const u9ns_input = 
        \\---
        \\time: 20:03:20
        \\player: Sammy Sosa
        \\action: strike (miss)
        \\...
        \\---
        \\time: 20:03:47
        \\player: Sammy Sosa
        \\action: grand slam
        \\...
        \\
    ;
    
    std.debug.print("Testing U9NS input:\n{s}\n", .{u9ns_input});
    
    const result = parser.parseStream(u9ns_input);
    if (result) |stream| {
        std.debug.print("✓ Successfully parsed stream with {} documents\n", .{stream.documents.items.len});
    } else |err| {
        std.debug.print("✗ Error parsing: {}\n", .{err});
    }
}