const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "%YAML 1.2 foo\n---\n";
    
    std.debug.print("Testing H7TQ (extra words on YAML directive):\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}