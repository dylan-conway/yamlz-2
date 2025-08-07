const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input =
        \\---
        \\[
        \\sequence item
        \\]
        \\invalid item
    ;

    std.debug.print("Testing KS4U: Invalid content after document end\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});

    var result = parser.parse(input) catch |err| {
        std.debug.print("PASS: Parser correctly rejected with error: {}\n", .{err});
        return;
    };
    defer result.deinit();

    std.debug.print("FAIL: Parser accepted invalid YAML\n", .{});
}
