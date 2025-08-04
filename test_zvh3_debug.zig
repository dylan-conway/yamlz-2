const std = @import("std");
const parser = @import("src/parser.zig");
const ast = @import("src/ast.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const input = 
        \\- key: value
        \\ - item1
        \\
    ;
    
    std.debug.print("Testing ZVH3 debug:\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    const result = parser.parseStream(input);
    
    if (result) |stream| {
        std.debug.print("Result: SUCCESS\n", .{});
        std.debug.print("Documents: {}\n", .{stream.documents.items.len});
        
        if (stream.documents.items.len > 0) {
            const doc = stream.documents.items[0];
            if (doc.root) |root| {
                std.debug.print("Root type: {}\n", .{root.type});
                if (root.type == .sequence) {
                    std.debug.print("Sequence items: {}\n", .{root.data.sequence.items.items.len});
                    for (root.data.sequence.items.items, 0..) |item, i| {
                        std.debug.print("  Item {}: type={}\n", .{i, item.type});
                    }
                }
            }
        }
    } else |err| {
        std.debug.print("Result: ERROR - {}\n", .{err});
    }
}