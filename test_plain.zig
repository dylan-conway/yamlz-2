const std = @import("std");
const parser = @import("src/parser.zig");
const Lexer = @import("src/lexer.zig").Lexer;

pub fn main() !void {
    // Test just the plain scalar parsing
    const yaml = 
        \\word1 word2
        \\no: key
    ;
    
    std.debug.print("Testing plain scalar:\n{s}\n", .{yaml});
    
    var p = parser.Parser.init(std.heap.page_allocator, yaml);
    const result = p.parsePlainScalar() catch |err| {
        std.debug.print("Plain scalar error: {any}\n", .{err});
        return;
    };
    
    std.debug.print("Plain scalar value: '{s}'\n", .{result.data.scalar.value});
}