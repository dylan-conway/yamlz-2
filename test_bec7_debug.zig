const std = @import("std");
const yaml = @import("src/yaml.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input =
        \\%YAML 1.3 # Attempt parsing
        \\          # with a warning
        \\---
        \\"foo"
    ;
    
    std.debug.print("Input:\n{s}\n\n", .{input});
    
    var parser = yaml.Parser.init(allocator);
    defer parser.deinit();
    
    const result = parser.parse(input);
    
    if (result) |docs| {
        defer docs.deinit();
        std.debug.print("Parse successful!\n", .{});
        std.debug.print("Number of documents: {}\n", .{docs.items.len});
        if (docs.items.len > 0) {
            const doc = docs.items[0];
            std.debug.print("Document value type: {}\n", .{@tagName(doc.root)});
            if (doc.root == .string) {
                std.debug.print("String value: {s}\n", .{doc.root.string});
            }
        }
    } else |err| {
        std.debug.print("Parse failed with error: {}\n", .{err});
        if (parser.error_info) |info| {
            std.debug.print("Error at line {}, column {}: {s}\n", .{ info.line, info.column, info.message });
        }
    }
}