const std = @import("std");
const parser_mod = @import("src/parser.zig");
const Parser = @import("src/parser.zig").Parser;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const input = 
        \\---
        \\x: { y: z }in: valid
    ;
    
    std.debug.print("Testing 62EZ input:\n{s}\n", .{input});
    
    // Let's trace through what the parser does
    var parser = try Parser.init(allocator, input);
    defer parser.deinit();
    
    const doc = parser.parseDocument() catch |err| {
        std.debug.print("Parser correctly rejected with error: {}\n", .{err});
        return;
    };
    
    std.debug.print("ERROR: Parser incorrectly accepted the invalid YAML\n", .{});
    _ = doc;
}