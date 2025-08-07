const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    const input = 
        \\word1  # comment
        \\word2
        \\
    ;
    
    std.debug.print("Testing BS4K input:\n{s}\n", .{input});
    
    var p = try parser.Parser.init(allocator, input);
    defer p.deinit();
    
    // Use parseStream to see what actually happens
    const stream = p.parseStream() catch |err| {
        std.debug.print("Parser error: {}\n", .{err});
        std.debug.print("Error occurred at position: {}/{}\n", .{p.lexer.pos, p.lexer.input.len});
        return;
    };
    
    std.debug.print("Number of documents: {}\n", .{stream.documents.items.len});
    
    if (stream.documents.items.len > 0) {
        const doc = stream.documents.items[0];
        if (doc.root) |root| {
            std.debug.print("First document root type: {}\n", .{root.type});
            if (root.type == .scalar) {
                std.debug.print("Scalar value: '{s}'\n", .{root.data.scalar.value});
            }
        }
    }
    
    std.debug.print("Parser position after stream: {}/{}\n", .{p.lexer.pos, p.lexer.input.len});
    if (p.lexer.pos < p.lexer.input.len) {
        std.debug.print("Remaining input: '{s}'\n", .{p.lexer.input[p.lexer.pos..]});
    }
}