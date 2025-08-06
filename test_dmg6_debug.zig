const std = @import("std");
const Lexer = @import("src/lexer.zig").Lexer;

pub fn main() !void {
    const input =
        \\key:
        \\  ok: 1
        \\ wrong: 2
        \\
    ;
    
    var lexer = Lexer.init(input);
    
    // Parse "key:"
    while (lexer.peek() != ':') lexer.advanceChar();
    lexer.advanceChar(); // skip ':'
    lexer.skipToEndOfLine();
    _ = lexer.skipLineBreak();
    
    // Now at "  ok: 1"
    std.debug.print("After 'key:', column: {}\n", .{lexer.column});
    
    // Skip to "ok"
    while (lexer.peek() == ' ') lexer.advanceChar();
    std.debug.print("At 'ok', column: {}\n", .{lexer.column});
    
    // Skip to next line
    lexer.skipToEndOfLine();
    _ = lexer.skipLineBreak();
    
    // Now at " wrong: 2"
    std.debug.print("At ' wrong', column: {}\n", .{lexer.column});
    
    // Count spaces
    var spaces: usize = 0;
    while (lexer.peek() == ' ') {
        lexer.advanceChar();
        spaces += 1;
    }
    std.debug.print("Found {} spaces before 'wrong'\n", .{spaces});
    std.debug.print("Now at column: {}\n", .{lexer.column});
}