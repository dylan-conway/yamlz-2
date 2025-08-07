const std = @import("std");
const Parser = @import("src/parser.zig").Parser;

pub fn main() !void {
    const input = 
        \\%YAML 1.3
        \\---
        \\"foo"
        \\
    ;
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var parser = try Parser.init(allocator, input);
    defer parser.deinit();
    
    const result = parser.parseDocument();
    
    if (result) |_| {
        std.debug.print("parseDocument accepted YAML 1.3\n", .{});
    } else |err| {
        std.debug.print("parseDocument rejected with error: {}\n", .{err});
    }
}