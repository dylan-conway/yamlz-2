const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test the problematic section more specifically
    const inputs = [_][]const u8{
        "seq:\t\n - a\t\n",  // This should be a key 'seq' with empty value and then a sequence item
        "seq:\n - a\t\n",    // Same without tab after seq:
        "a: b\t\nseq:\t\n",  // Two keys without the sequence item
    };
    
    for (inputs, 0..) |test_input, i| {
        std.debug.print("Testing input {}: '{}'\n", .{i + 1, std.fmt.fmtSliceEscapeLower(test_input)});
        var p = try parser.Parser.init(allocator, test_input);
        defer p.deinit();
        
        const result = p.parseStream();
        if (result) |stream| {
            std.debug.print("  Success: parsed {} documents\n", .{stream.documents.items.len});
        } else |err| {
            std.debug.print("  Error: {}\n", .{err});
        }
    }
}