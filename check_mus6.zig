const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const test_cases = [_]struct {
        name: []const u8,
        input: []const u8,
        should_error: bool,
    }{
        .{ .name = "MUS6/00", .input = "%YAML 1.1#...\n---\n", .should_error = true },
        .{ .name = "MUS6/01", .input = "%YAML 1.2\n---\n%YAML 1.2\n---\n", .should_error = true },
        .{ .name = "MUS6/02", .input = "%YAML  1.1\n---\n", .should_error = false },
        .{ .name = "MUS6/03", .input = "%YAML \t 1.1\n---\n", .should_error = false },
        .{ .name = "MUS6/04", .input = "%YAML 1.1  # comment\n---\n", .should_error = false },
        .{ .name = "MUS6/05", .input = "%YAM 1.1\n---\n", .should_error = false },
        .{ .name = "MUS6/06", .input = "%YAMLL 1.1\n---\n", .should_error = false },
    };
    
    std.debug.print("=== Testing MUS6 variants ===\n", .{});
    
    for (test_cases) |tc| {
        std.debug.print("\n{s}: ", .{tc.name});
        
        var p = parser.Parser.init(allocator, tc.input);
        defer p.deinit();
        
        const result = p.parse();
        
        if (tc.should_error) {
            if (result) |_| {
                std.debug.print("FAIL - Expected error but parsed successfully\n", .{});
            } else |_| {
                std.debug.print("PASS - Got expected error\n", .{});
            }
        } else {
            if (result) |_| {
                std.debug.print("PASS - Parsed successfully\n", .{});
            } else |err| {
                std.debug.print("FAIL - Got unexpected error: {}\n", .{err});
            }
        }
    }
}