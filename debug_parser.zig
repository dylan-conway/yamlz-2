const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const input = "name: Mark McGwire\naccomplishment: >\n  Mark set a major league\n  home run record in 1998.\nstats: |\n  65 Home Runs\n  0.278 Batting Average";
    std.debug.print("Input: {s}\n", .{input});
    std.debug.print("Character codes: ", .{});
    for (input) |ch| {
        std.debug.print("{} ", .{ch});
    }
    std.debug.print("\n", .{});
    
    var p = parser.Parser.init(gpa.allocator(), input);
    defer p.deinit();
    
    const result = p.parseDocument() catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        std.debug.print("At position: {}, line: {}, column: {}\n", .{p.lexer.pos, p.lexer.line, p.lexer.column});
        std.debug.print("Character at error: '{}' ({})\n", .{p.lexer.peek(), p.lexer.peek()});
        return;
    };
    std.debug.print("Parse success!\n", .{});
    _ = result;
}