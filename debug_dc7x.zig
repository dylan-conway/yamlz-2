const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test each line individually to isolate the issue
    const inputs = [_][]const u8{
        "a: b\t\n",
        "seq:\t\n",
        " - a\t\n",
        "c: d\t#X\n",
    };
    
    for (inputs, 0..) |test_input, i| {
        std.debug.print("Testing line {}: '{}'\n", .{i + 1, std.fmt.fmtSliceEscapeLower(test_input)});
        var p = try parser.Parser.init(allocator, test_input);
        defer p.deinit();
        
        const result = p.parseStream();
        if (result) |stream| {
            std.debug.print("  Success: parsed {} documents\n", .{stream.documents.items.len});
        } else |err| {
            std.debug.print("  Error: {}\n", .{err});
        }
    }
    
    std.debug.print("\nTesting full input:\n", .{});
    const input = "a: b\t\nseq:\t\n - a\t\nc: d\t#X\n";
    
    var p = try parser.Parser.init(allocator, input);
    defer p.deinit();
    
    const result = p.parseStream();
    if (result) |stream| {
        std.debug.print("Success: parsed {} documents\n", .{stream.documents.items.len});
    } else |err| {
        std.debug.print("Error: {}\n", .{err});
    }
}