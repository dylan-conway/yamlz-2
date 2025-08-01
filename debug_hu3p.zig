const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const input = "key:\n  word1 word2\n  no: key";
    std.debug.print("Testing HU3P case: {s}\n", .{input});
    
    var p = parser.Parser.init(gpa.allocator(), input);
    defer p.deinit();
    
    const result = p.parseDocument() catch |err| {
        std.debug.print("Parse error (EXPECTED): {}\n", .{err});
        std.debug.print("At position: {}, line: {}, column: {}\n", .{p.lexer.pos, p.lexer.line, p.lexer.column});
        if (p.lexer.pos < input.len) {
            std.debug.print("Character at error: '{c}' ({})\n", .{input[p.lexer.pos], input[p.lexer.pos]});
        }
        return;
    };
    std.debug.print("Parse success (UNEXPECTED - should have failed!)\n", .{});
    _ = result;
}