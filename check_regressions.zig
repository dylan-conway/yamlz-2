const std = @import("std");
const parser = @import("src/parser.zig");

const test_cases = [_]struct {
    name: []const u8,
    input: []const u8,
    should_pass: bool,
}{
    // Some basic valid cases that should pass
    .{ .name = "Basic sequence", .input = "- item1\n- item2", .should_pass = true },
    .{ .name = "Flow in block", .input = "- { key: value }", .should_pass = true },
    .{ .name = "Flow with comment", .input = "- { key: value } # comment", .should_pass = true },
    .{ .name = "Multiple flows", .input = "- { a: 1 }\n- { b: 2 }", .should_pass = true },
    .{ .name = "Nested flow", .input = "- { a: { b: c } }", .should_pass = true },
    
    // Invalid cases
    .{ .name = "P2EQ case", .input = "- { y: z }- invalid", .should_pass = false },
    .{ .name = "Content after flow", .input = "- { y: z } extra", .should_pass = false },
};

pub fn main() !void {
    var passing: usize = 0;
    var failing: usize = 0;
    
    for (test_cases) |tc| {
        const result = parser.parse(tc.input) catch |err| {
            if (tc.should_pass) {
                std.debug.print("FAIL: '{s}' should pass but got error: {}\n", .{ tc.name, err });
                failing += 1;
            } else {
                std.debug.print("PASS: '{s}' correctly rejected\n", .{tc.name});
                passing += 1;
            }
            continue;
        };
        _ = result;
        
        if (!tc.should_pass) {
            std.debug.print("FAIL: '{s}' should fail but passed\n", .{tc.name});
            failing += 1;
        } else {
            std.debug.print("PASS: '{s}' correctly accepted\n", .{tc.name});
            passing += 1;
        }
    }
    
    std.debug.print("\nResults: {} passing, {} failing\n", .{ passing, failing });
}