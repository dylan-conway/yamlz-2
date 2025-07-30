const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const yaml = 
        \\a:
        \\  b:
        \\    c: d
        \\  e:
        \\    f: g
        \\h: i
    ;
    
    std.debug.print("Testing 9FMG case:\n{s}\n", .{yaml});
    
    const doc = parser.parse(yaml) catch |err| {
        std.debug.print("Parser error: {any}\n", .{err});
        return;
    };
    
    _ = doc;
    std.debug.print("Parser succeeded\n", .{});
}