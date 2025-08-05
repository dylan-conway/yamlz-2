const std = @import("std");
const Parser = @import("src/parser.zig").Parser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    const input = "\t[\n\t]";
    
    std.debug.print("Input: {s}\n", .{input});
    
    var parser = try Parser.init(gpa.allocator(), input);
    defer parser.deinit();
    
    const result = parser.parseDocument();
    
    if (result) |doc| {
        std.debug.print("Parse successful!\n", .{});
        _ = doc;
    } else |err| {
        std.debug.print("Parse error: {}\n", .{err});
    }
}