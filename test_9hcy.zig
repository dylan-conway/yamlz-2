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
    
    const result = parser.parseStream(input);
    if (result) |stream| {
        std.debug.print("UNEXPECTED: Parser accepted invalid YAML!\n", .{});
        std.debug.print("Stream has {} documents\n", .{stream.documents.items.len});
    } else |err| {
        std.debug.print("EXPECTED: Parser correctly rejected with error: {}\n", .{err});
    }
}