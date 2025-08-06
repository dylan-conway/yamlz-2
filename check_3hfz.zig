const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Read the actual test file
    const file = try std.fs.cwd().openFile("yaml-test-suite/3HFZ/in.yaml", .{});
    defer file.close();
    
    var buffer: [1024]u8 = undefined;
    const bytes_read = try file.read(&buffer);
    const input = buffer[0..bytes_read];
    
    std.debug.print("Testing 3HFZ with actual test file content:\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    // This test expects an error (has error file)
    const doc = parser.parse(input) catch |err| {
        std.debug.print("✓ Test 3HFZ PASSED - Parser correctly rejected with error: {}\n", .{err});
        return;
    };
    
    _ = doc;
    std.debug.print("✗ Test 3HFZ FAILED - Parser incorrectly accepted the input\n", .{});
    std.process.exit(1);
}