const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Test GT5M case - floating anchor
    const input1 = "- item1\n&node\n- item2";
    std.debug.print("Testing GT5M case: {s}\n", .{input1});
    
    var p1 = parser.Parser.init(gpa.allocator(), input1);
    defer p1.deinit();
    
    const result1 = p1.parseDocument() catch |err| {
        std.debug.print("Parse error (EXPECTED): {}\n", .{err});
        std.debug.print("At position: {}, line: {}, column: {}\n", .{p1.lexer.pos, p1.lexer.line, p1.lexer.column});
        return;
    };
    std.debug.print("Parse success (UNEXPECTED - should have failed!)\n", .{});
    _ = result1;
    
    std.debug.print("\n", .{});
    
    // Test 4JVG case - anchor on mapping key
    const input2 = "top1: &node1\n  &k1 key1: val1\ntop2: &node2\n  &v2 val2";
    std.debug.print("Testing 4JVG case: {s}\n", .{input2});
    
    var p2 = parser.Parser.init(gpa.allocator(), input2);
    defer p2.deinit();
    
    const result2 = p2.parseDocument() catch |err| {
        std.debug.print("Parse error (EXPECTED): {}\n", .{err});
        std.debug.print("At position: {}, line: {}, column: {}\n", .{p2.lexer.pos, p2.lexer.line, p2.lexer.column});
        return;
    };
    std.debug.print("Parse success (UNEXPECTED - should have failed!)\n", .{});
    _ = result2;
}