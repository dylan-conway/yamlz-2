const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\---
        \\scalar
        \\%YAML 1.2
        \\
    ;
    
    std.debug.print("Testing XLQ9 input:\n{s}\n", .{input});
    std.debug.print("Expected output: scalar %YAML 1.2\n\n", .{});
    
    const doc = parser.parse(input) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        std.debug.print("TEST FAILED: Parser rejected valid YAML\n", .{});
        return;
    };
    
    if (doc.root) |root| {
        if (root.type == .scalar) {
            const scalar = root.data.scalar;
            std.debug.print("Parsed scalar value: '{s}'\n", .{scalar.value});
            
            const expected = "scalar %YAML 1.2";
            if (std.mem.eql(u8, scalar.value, expected)) {
                std.debug.print("TEST PASSED: Correctly parsed multiline scalar\n", .{});
            } else {
                std.debug.print("TEST FAILED: Expected '{s}', got '{s}'\n", .{expected, scalar.value});
            }
        } else {
            std.debug.print("TEST FAILED: Expected scalar, got {}\n", .{root.type});
        }
    } else {
        std.debug.print("TEST FAILED: No root node\n", .{});
    }
}