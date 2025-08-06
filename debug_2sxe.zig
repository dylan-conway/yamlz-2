const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Let's try to parse the full YAML now
    const input = "&a: key: &a value\nfoo:\n  *a:";
    
    var yaml_parser = parser.Parser.init(allocator, input) catch |err| {
        std.debug.print("Failed to init parser: {}\n", .{err});
        return;
    };
    defer yaml_parser.deinit();
    
    std.debug.print("Parsing: '{s}'\n", .{input});
    
    _ = yaml_parser.parseDocument() catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        
        // Print anchor map even on error to see what was registered
        std.debug.print("Anchors in map at error:\n", .{});
        var iterator = yaml_parser.anchors.iterator();
        while (iterator.next()) |entry| {
            std.debug.print("  '{s}'\n", .{entry.key_ptr.*});
        }
        return;
    };
    
    std.debug.print("Parsed successfully!\n", .{});
    
    // Print anchor map
    std.debug.print("Anchors in map:\n", .{});
    var iterator = yaml_parser.anchors.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("  '{s}'\n", .{entry.key_ptr.*});
    }
}