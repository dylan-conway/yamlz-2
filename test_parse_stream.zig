const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "%YAML 1.2 foo\n---\n";
    std.debug.print("Testing H7TQ via parseStream: Extra words on %YAML directive\n", .{});
    std.debug.print("Input: {s}\n", .{input});
    
    var p = try parser.Parser.init(allocator, input);
    defer p.deinit();
    
    const result = p.parseStream();
    
    if (result) |stream| {
        std.debug.print("FAIL: parseStream accepted invalid YAML (should reject extra words after version)\n", .{});
        std.debug.print("Stream has {} documents\n", .{stream.documents.items.len});
    } else |err| {
        std.debug.print("PASS: parseStream correctly rejected with error: {}\n", .{err});
    }
}