const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const yaml = 
        \\key:
        \\  word1 word2
        \\  no: key
    ;
    
    std.debug.print("Testing HU3P case:\n{s}\n", .{yaml});
    
    const doc = parser.parse(yaml) catch |err| {
        std.debug.print("Parser error (expected): {any}\n", .{err});
        return;
    };
    
    if (doc.root) |root| {
        if (root.type == .mapping) {
            const pairs = root.data.mapping.pairs;
            if (pairs.items.len > 0) {
                const pair = pairs.items[0];
                if (pair.key.type == .scalar) {
                    std.debug.print("Key: {s}\n", .{pair.key.data.scalar.value});
                }
                if (pair.value.type == .scalar) {
                    std.debug.print("Value: '{s}'\n", .{pair.value.data.scalar.value});
                    std.debug.print("Value length: {}\n", .{pair.value.data.scalar.value.len});
                }
            }
        }
    }
    std.debug.print("Parser succeeded (unexpected - should have failed)\n", .{});
}