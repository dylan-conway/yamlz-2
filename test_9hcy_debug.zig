const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\!foo "bar"
        \\%TAG ! tag:example.com,2000:app/
        \\---
        \\!foo "bar"
    ;
    
    std.debug.print("Testing 9HCY input:\n{s}\n\n", .{input});
    
    // Also test each line to understand what's happening
    const lines = [_][]const u8{
        "!foo \"bar\"",
        "!foo \"bar\"\n%TAG ! tag:example.com,2000:app/",
    };
    
    for (lines, 0..) |line, i| {
        std.debug.print("\nTest {}: {s}\n", .{i + 1, line});
        const result = parser.parseStream(line);
        if (result) |stream| {
            std.debug.print("  Accepted - {} documents\n", .{stream.documents.items.len});
        } else |err| {
            std.debug.print("  Rejected - error: {}\n", .{err});
        }
    }
}