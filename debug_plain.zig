const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test the exact scenario from HU3P
    // Starting position should be after "key:" at column 3
    const yaml = "key:\n  word1 word2\n  no: key";
    
    std.debug.print("Testing plain scalar parsing:\n", .{});
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    var p = parser.Parser.init(arena.allocator(), yaml);
    
    // Parse the document
    const doc = p.parseDocument() catch |err| {
        std.debug.print("Parse error: {any}\n", .{err});
        return;
    };
    
    std.debug.print("Parse succeeded\n", .{});
    
    if (doc.root) |root| {
        if (root.type == .mapping) {
            const pairs = root.data.mapping.pairs;
            for (pairs.items) |pair| {
                std.debug.print("Key: {s}\n", .{pair.key.data.scalar.value});
                if (pair.value.type == .scalar) {
                    std.debug.print("Value: '{s}' (len={})\n", .{
                        pair.value.data.scalar.value,
                        pair.value.data.scalar.value.len
                    });
                    // Show bytes
                    for (pair.value.data.scalar.value) |byte| {
                        if (byte == '\n') {
                            std.debug.print("\\n", .{});
                        } else {
                            std.debug.print("{c}", .{byte});
                        }
                    }
                    std.debug.print("\n", .{});
                }
            }
        }
    }
}