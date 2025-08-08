const std = @import("std");
const parser = @import("src/parser.zig");
const Lexer = @import("src/lexer.zig").Lexer;

pub fn main() !void {
    const input = "- { y: z }- invalid";
    
    std.debug.print("Parsing: '{s}'\n\n", .{input});
    
    // Create a GeneralPurposeAllocator for the parser
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a parser to get more detail
    var p = try parser.Parser.init(allocator, input);
    defer p.deinit();
    
    // Advance past "- "
    p.lexer.advanceChar(); // skip '-'
    p.lexer.advanceChar(); // skip ' '
    
    std.debug.print("Before parseValue, at pos {}: '{}'\n", .{p.lexer.pos, p.lexer.peek()});
    
    // This should parse { y: z }
    const value = try p.parseValue(0);
    _ = value;
    
    std.debug.print("After parseValue, at pos {}: '{}'\n", .{p.lexer.pos, p.lexer.peek()});
    std.debug.print("Remaining input: '{s}'\n", .{p.lexer.input[p.lexer.pos..]});
    
    // Now check what the parser would do with the rest
    if (!p.lexer.isEOF() and !Lexer.isLineBreak(p.lexer.peek())) {
        std.debug.print("\nThere is content after the value!\n", .{});
        std.debug.print("Next char: '{}' (ASCII {})\n", .{p.lexer.peek(), p.lexer.peek()});
        
        // Check if it's being treated as another sequence item
        if (p.lexer.peek() == '-') {
            std.debug.print("ERROR: This looks like another sequence indicator, which is invalid on the same line!\n", .{});
        }
    }
}