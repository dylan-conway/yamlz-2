const std = @import("std");
const parser = @import("src/parser.zig");
const ast = @import("src/ast.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = 
        \\- key: value
        \\ - item1
        \\
    ;
    
    std.debug.print("Testing ZVH3 (should fail but currently passes):\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    
    const result = parser.parseStream(input);
    
    if (result) |doc| {
        std.debug.print("Result: SUCCESS (this is wrong - should have failed)\n", .{});
        std.debug.print("Parsed as Stream with {} documents\n", .{doc.documents.items.len});
    } else |err| {
        std.debug.print("Result: ERROR - {}\n", .{err});
    }
}