const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Run test suite and capture output
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{"./zig/zig", "build", "test-yaml", "--", "zig", "--verbose"},
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    
    // Count failure types
    var expected_error_got_success: u32 = 0;
    var expected_success_got_error: u32 = 0;
    
    const output = if (result.stderr.len > 0) result.stderr else result.stdout;
    var lines = std.mem.tokenizeScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "(expected error, got success)") != null) {
            expected_error_got_success += 1;
        } else if (std.mem.indexOf(u8, line, "(expected success, got error)") != null) {
            expected_success_got_error += 1;
        }
    }
    
    std.debug.print("\nFailure Analysis:\n", .{});
    std.debug.print("Expected error but got success (too permissive): {}\n", .{expected_error_got_success});
    std.debug.print("Expected success but got error (too strict): {}\n", .{expected_success_got_error});
    std.debug.print("Total failures: {}\n", .{expected_error_got_success + expected_success_got_error});
}