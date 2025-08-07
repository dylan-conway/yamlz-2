const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\[
        \\? foo
        \\ bar : baz
        \\]
    ;
    
    std.debug.print("Testing CT4Q:\n{s}\n", .{input});
    
    var result = parser.parse(input) catch |err| {
        std.debug.print("Parser error: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    std.debug.print("Parse successful!\n", .{});
}