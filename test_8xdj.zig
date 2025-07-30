const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const yaml = 
        \\key: word1
        \\#  xxx  
        \\  word2
    ;
    
    std.debug.print("Testing 8XDJ case:\n{s}\n", .{yaml});
    
    const doc = parser.parse(yaml) catch |err| {
        std.debug.print("Parser error (expected): {any}\n", .{err});
        return;
    };
    
    if (doc.root) |root| {
        if (root.type == .mapping) {
            const pairs = root.data.mapping.pairs;
            if (pairs.items.len > 0) {
                const pair = pairs.items[0];
                if (pair.value.type == .scalar) {
                    std.debug.print("Value: '{s}'\n", .{pair.value.data.scalar.value});
                }
            }
        }
    }
    std.debug.print("Parser succeeded (unexpected - should have failed)\n", .{});
}