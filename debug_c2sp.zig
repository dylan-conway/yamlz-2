const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "[23\n]: 42";
    
    std.debug.print("Input: {s}\n", .{input});
    std.debug.print("Input bytes: ", .{});
    for (input) |byte| {
        std.debug.print("{} ", .{byte});
    }
    std.debug.print("\n", .{});
    
    // Create a GeneralPurposeAllocator for the parser
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create parser to check internal state
    const parser_ptr = try allocator.create(parser.Parser);
    parser_ptr.* = try parser.Parser.init(allocator, input);
    
    std.debug.print("Initial lexer state: pos={}, line={}, peek='{}'\n", .{parser_ptr.lexer.pos, parser_ptr.lexer.line, parser_ptr.lexer.peek()});
    
    const result = parser.parse(input);
    if (result) |doc| {
        std.debug.print("Parse succeeded - this should fail!\n", .{});
        std.debug.print("Final lexer state: pos={}, line={}, peek='{}'\n", .{parser_ptr.lexer.pos, parser_ptr.lexer.line, parser_ptr.lexer.peek()});
        if (doc.root) |root| {
            std.debug.print("Root type: {}\n", .{root.type});
        }
    } else |err| {
        std.debug.print("Parse failed with error: {}\n", .{err});
    }
}