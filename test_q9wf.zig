const std = @import("std");
const parser_mod = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\{ first: Sammy, last: Sosa }:
        \\# Statistics:
        \\  hr:  # Home runs
        \\     65
        \\  avg: # Average
        \\   0.278
    ;
    
    std.debug.print("Testing Q9WF input:\n{s}\n", .{input});
    
    const doc = parser_mod.parse(input) catch |err| {
        std.debug.print("Parser incorrectly rejected with error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parser correctly accepted the valid YAML\n", .{});
    _ = doc;
}