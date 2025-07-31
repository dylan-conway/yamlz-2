const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(input);
    
    // Remove trailing newline if present
    const trimmed_input = std.mem.trimRight(u8, input, "\n\r");
    
    var p = parser.Parser.init(allocator, trimmed_input);
    defer p.deinit();
    
    // Add debug output
    std.debug.print("Input:\n{s}\n---\n", .{trimmed_input});
    
    const doc = p.parseDocument() catch |err| {
        std.debug.print("Parse error: {s} at line {} col {}\n", .{@errorName(err), p.lexer.line, p.lexer.column});
        return;
    };
    
    std.debug.print("Parse successful\n", .{});
    
    // Try parsing with the public parse function
    const doc2 = parser.parse(trimmed_input) catch |err| {
        std.debug.print("Public parse error: {s}\n", .{@errorName(err)});
        return;
    };
    _ = doc2;
    _ = doc;
    
    std.debug.print("Both parsers successful\n", .{});
}