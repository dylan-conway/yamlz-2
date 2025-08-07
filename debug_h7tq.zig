const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "%YAML 1.2 foo\n---\n";
    std.debug.print("Testing H7TQ: Extra words on %YAML directive\n", .{});
    std.debug.print("Input: {s}\n", .{input});
    
    var p = try parser.Parser.init(allocator, input);
    defer p.deinit();
    
    // Let's trace through the directive parsing
    std.debug.print("Starting parse...\n", .{});
    const result = p.parseDocument();
    
    if (result) |doc| {
        std.debug.print("FAIL: Parser accepted invalid YAML (should reject extra words after version)\n", .{});
        std.debug.print("Document parsed with root: {}\n", .{doc.root != null});
    } else |err| {
        std.debug.print("PASS: Parser correctly rejected with error: {}\n", .{err});
    }
}