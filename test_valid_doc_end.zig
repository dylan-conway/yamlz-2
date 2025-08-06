const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test valid document end markers
    const test_cases = [_][]const u8{
        // Valid: document end with nothing after
        \\---
        \\key: value
        \\...
        ,
        // Valid: document end with comment
        \\---
        \\key: value
        \\... # comment
        ,
        // Valid: document end with whitespace
        \\---
        \\key: value
        \\...   
        ,
        // Valid: new document after document end
        \\---
        \\key1: value1
        \\...
        \\---
        \\key2: value2
        ,
    };
    
    for (test_cases, 0..) |input, i| {
        std.debug.print("\nTest case {}:\n", .{i + 1});
        const result = parser.parseStream(input) catch |err| {
            std.debug.print("✗ Failed to parse valid YAML: {}\n", .{err});
            std.debug.print("Input:\n{s}\n", .{input});
            std.process.exit(1);
        };
        _ = result;
        std.debug.print("✓ Correctly accepted valid document end marker\n", .{});
    }
    
    std.debug.print("\nAll valid document end marker tests passed!\n", .{});
}