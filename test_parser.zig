const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Read input from stdin
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, 1024 * 1024); // 1MB max
    defer allocator.free(input);
    
    // Parse the YAML
    _ = parser.parse(input) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parse successful!\n", .{});
}