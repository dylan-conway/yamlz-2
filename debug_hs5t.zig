const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = "1st non-empty\n\n 2nd non-empty \n\t3rd non-empty\n\n";
    
    std.debug.print("Input YAML:\n'{s}'\n", .{input});
    std.debug.print("Input bytes: ", .{});
    for (input) |byte| {
        std.debug.print("{} ", .{byte});
    }
    std.debug.print("\n", .{});
    
    const result = parser.parse(input);
    if (result) |_| {
        std.debug.print("Parse succeeded\n", .{});
    } else |err| {
        std.debug.print("Parse failed with error: {}\n", .{err});
    }
}