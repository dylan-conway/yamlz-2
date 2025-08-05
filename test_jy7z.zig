const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\key1: "quoted1"
        \\key2: "quoted2" no key: nor value
        \\key3: "quoted3"
    ;
    
    std.debug.print("Testing JY7Z (trailing content with colon after quoted):\n", .{});
    
    const doc = parser.parse(input) catch |e| {
        std.debug.print("Got error as expected: {}\n", .{e});
        return;
    };
    _ = doc;
    std.debug.print("ERROR: Should have failed but parsed successfully!\n", .{});
}