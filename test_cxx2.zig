const std = @import("std");
const Parser = @import("src/parser.zig").Parser;

test "CXX2 test" {
    const input = "--- &anchor a: b\n";
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var parser = Parser.init(arena.allocator(), input);
    const result = parser.parseStream();
    
    // This should fail
    std.testing.expect(result == error.InvalidDocumentStructure) catch |err| {
        std.debug.print("Expected error.InvalidDocumentStructure, got: {}\n", .{result});
        return err;
    };
}