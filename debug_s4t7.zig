const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const yaml_input = "aaa: bbb\n...\n";
    
    std.debug.print("Input: {s}\n", .{yaml_input});
    std.debug.print("Input bytes: ", .{});
    for (yaml_input) |byte| {
        std.debug.print("{} ", .{byte});
    }
    std.debug.print("\n", .{});
    
    const doc = parser.parse(yaml_input) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parse successful!\n", .{});
    _ = doc;
}