const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const stdin = std.io.getStdIn();
    const input = try stdin.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
    defer allocator.free(input);
    
    _ = parser.parse(input) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        std.process.exit(1);
    };
    
    std.debug.print("Parse succeeded\n", .{});
}