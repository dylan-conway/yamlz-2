const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "- !!str, xxx\n";
    
    std.debug.print("Testing U99R: {s}", .{input});
    
    var p = try parser.Parser.init(allocator, input);
    defer p.deinit();
    
    const doc = p.parseDocument() catch |err| {
        std.debug.print("Parser correctly rejected invalid YAML with error: {}\n", .{err});
        return;
    };
    _ = doc;
    
    std.debug.print("ERROR: Parser incorrectly accepted invalid YAML (should reject comma in tag)\n", .{});
}