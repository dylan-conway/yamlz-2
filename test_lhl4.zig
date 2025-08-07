const std = @import("std");
const Parser = @import("src/parser.zig").Parser;

pub fn main() !void {
    // Try different formats
    const inputs = [_][]const u8{
        "!invalid{}tag scalar\n",
        "!tag {}",  // Valid: tag followed by empty flow mapping
        "!tag{} value",  // Should this be valid?
        "{}tag scalar",  // Just the problematic part
    };
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    for (inputs, 0..) |input, i| {
        std.debug.print("\n--- Test {} ---\n", .{i});
        std.debug.print("Input: '{s}'\n", .{input});
        
        var parser = try Parser.init(allocator, input);
        defer parser.deinit();
        
        const doc = parser.parseDocument() catch |err| {
            std.debug.print("Parse error: {}\n", .{err});
            continue;
        };
        
        std.debug.print("Parse succeeded!\n", .{});
        
        if (doc.root) |root| {
            std.debug.print("Root type: {}\n", .{root.type});
            
            if (root.type == .scalar) {
                std.debug.print("Scalar value: '{s}'\n", .{root.data.scalar.value});
                if (root.tag) |tag| {
                    std.debug.print("Tag: '{s}'\n", .{tag});
                }
            }
        } else {
            std.debug.print("Document has no root node\n", .{});
        }
    }
}