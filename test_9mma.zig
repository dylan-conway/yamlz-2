const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "%YAML 1.2\n";
    
    std.debug.print("Testing 9MMA (directive without document):\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}