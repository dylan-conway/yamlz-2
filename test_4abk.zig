const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\{
        \\unquoted : "separate",
        \\http://foo.com,
        \\omitted value:,
        \\}
    ;
    
    std.debug.print("Testing 4ABK (flow mapping with URLs):\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("ERROR: Got unexpected error: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("SUCCESS: Parsed correctly\n", .{});
}