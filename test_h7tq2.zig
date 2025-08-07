const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "%YAML 1.2 foo\n---\n";
    std.debug.print("Testing H7TQ: Extra words on %YAML directive\n", .{});
    std.debug.print("Input: {s}\n", .{input});
    
    const result = parser.parse(input);
    
    if (result) |_| {
        std.debug.print("FAIL: Parser accepted invalid YAML (should reject extra words after version)\n", .{});
    } else |err| {
        std.debug.print("PASS: Parser correctly rejected with error: {}\n", .{err});
    }
}