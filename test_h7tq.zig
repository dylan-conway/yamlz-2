const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "%YAML 1.2 foo\n---\n";
    std.debug.print("Testing H7TQ: Extra words on %YAML directive\n", .{});
    std.debug.print("Input: {s}\n", .{input});
    
    var p = parser.Parser.init(allocator, input);
    defer p.deinit();
    
    const result = p.parse();
    
    if (result) |_| {
        std.debug.print("FAIL: Parser accepted invalid YAML (should reject extra words after version)\n", .{});
    } else |err| {
        std.debug.print("PASS: Parser correctly rejected with error: {}\n", .{err});
    }
}