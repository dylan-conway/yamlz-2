const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\a: &anchor
        \\  key: value
        \\b: *anchor
    ;
    
    const doc = try parser.parse(input);
    _ = doc;
    std.debug.print("Anchor test passed!\n", .{});
}