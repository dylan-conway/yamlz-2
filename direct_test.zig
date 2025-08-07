const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test the exact 62EZ content 
    const test_cases = [_]struct {
        name: []const u8,
        input: []const u8,
        should_fail: bool,
    }{
        .{
            .name = "62EZ",
            .input = "---\nx: { y: z }in: valid\n",
            .should_fail = true,
        },
        .{
            .name = "Q9WF",  
            .input = "{ first: Sammy, last: Sosa }:\n# Statistics:\n  hr:  # Home runs\n     65\n  avg: # Average\n   0.278\n",
            .should_fail = false,
        },
    };
    
    for (test_cases) |tc| {
        std.debug.print("\nTesting {s}:\n", .{tc.name});
        const result = parser.parse(tc.input) catch |err| {
            if (tc.should_fail) {
                std.debug.print("✓ Correctly rejected with: {}\n", .{err});
            } else {
                std.debug.print("✗ Incorrectly rejected with: {}\n", .{err});
            }
            continue;
        };
        _ = result;
        
        if (tc.should_fail) {
            std.debug.print("✗ Incorrectly accepted (should have failed)\n", .{});
        } else {
            std.debug.print("✓ Correctly accepted\n", .{});
        }
    }
}