const std = @import("std");
const Lexer = @import("src/lexer.zig").Lexer;

pub fn main() !void {
    const input = "- { y: z }- invalid";
    var lexer = Lexer.init(input);
    
    std.debug.print("Initial input: '{s}'\n", .{input});
    
    // Skip '-' 
    std.debug.print("At pos {}: '{}'\n", .{lexer.pos, lexer.peek()});
    lexer.advanceChar();
    
    // Skip space
    std.debug.print("At pos {}: '{}'\n", .{lexer.pos, lexer.peek()});
    lexer.advanceChar();
    
    // At '{'
    std.debug.print("At pos {}: '{}'\n", .{lexer.pos, lexer.peek()});
    
    // Simulate parsing flow mapping
    // Would consume: { y: z }
    while (lexer.peek() != '}' and !lexer.isEOF()) {
        lexer.advanceChar();
    }
    if (lexer.peek() == '}') {
        lexer.advanceChar(); // consume '}'
    }
    
    std.debug.print("After flow mapping, at pos {}: '{}' (ASCII {})\n", .{lexer.pos, lexer.peek(), lexer.peek()});
    std.debug.print("Remaining: '{s}'\n", .{lexer.input[lexer.pos..]});
    
    // Check what's next
    if (!lexer.isEOF() and !Lexer.isLineBreak(lexer.peek())) {
        std.debug.print("ERROR: There's content after the flow mapping!\n", .{});
        std.debug.print("Next char is '{}' (ASCII {})\n", .{lexer.peek(), lexer.peek()});
    }
}