const std = @import("std");
const Parser = @import("src/parser.zig").Parser;

pub fn main() !void {
    const input = "--- &anchor a: b\n";
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    var parser = Parser.init(arena.allocator(), input);
    const result = parser.parseStream();
    
    std.debug.print("Input: {s}\n", .{input});
    std.debug.print("Result: {}\n", .{result});
    
    if (result == error.InvalidDocumentStructure) {
        std.debug.print("✓ Correctly rejected invalid YAML\n");
    } else {
        std.debug.print("✗ Should have rejected invalid YAML\n");
    }
}