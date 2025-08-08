const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "[23\n]: 42";
    
    std.debug.print("Input: {s}\n", .{input});
    std.debug.print("Input bytes: ", .{});
    for (input) |byte| {
        std.debug.print("{} ", .{byte});
    }
    std.debug.print("\n", .{});
    
    // Create parser to check internal state
    var parser_instance = parser.Parser.init(allocator, input);
    defer parser_instance.deinit();
    
    std.debug.print("Initial lexer state: pos={}, line={}, peek='{}'\n", .{parser_instance.lexer.pos, parser_instance.lexer.line, parser_instance.lexer.peek()});
    
    const result = parser.parse(allocator, input);
    if (result) |doc| {
        std.debug.print("Parse succeeded - this should fail!\n", .{});
        std.debug.print("Final lexer state: pos={}, line={}, peek='{}'\n", .{parser_instance.lexer.pos, parser_instance.lexer.line, parser_instance.lexer.peek()});
        if (doc.root) |root| {
            std.debug.print("Root type: {}\n", .{root.type});
        }
    } else |err| {
        std.debug.print("Parse failed with error: {}\n", .{err});
    }
}