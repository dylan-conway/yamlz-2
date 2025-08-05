const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Read the exact same file that the test runner reads
    const file = std.fs.cwd().openFile("yaml-test-suite/2G84/00/in.yaml", .{}) catch |err| {
        std.debug.print("Failed to open file: {}\n", .{err});
        return;
    };
    defer file.close();
    
    const content = file.readToEndAlloc(std.heap.page_allocator, 1024) catch |err| {
        std.debug.print("Failed to read file: {}\n", .{err});
        return;
    };
    defer std.heap.page_allocator.free(content);
    
    std.debug.print("File content: '{}'\n", .{std.fmt.fmtSliceEscapeUpper(content)});
    std.debug.print("File length: {} bytes\n", .{content.len});
    
    const result = parser.parse(content);
    if (result) |_| {
        std.debug.print("SUCCESS: Parser accepted the input (this is BAD - should reject)\n", .{});
    } else |err| {
        std.debug.print("ERROR: Parser rejected the input (this is GOOD): {}\n", .{err});
    }
}