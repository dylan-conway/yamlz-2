const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const yaml_input = "? a\n: -\tb\n  -  -\tc\n     - d";
    
    std.debug.print("Testing A2M4 input:\n{s}\n\n", .{yaml_input});
    
    const doc = parser.parse(yaml_input) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parse succeeded!\n", .{});
    _ = doc;
}