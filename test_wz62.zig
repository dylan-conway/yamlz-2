const std = @import("std");
const Parser = @import("src/parser.zig").Parser;

pub fn main() !void {
    const input =
        \\{
        \\  foo : !!str,
        \\  !!str : bar,
        \\}
        \\
    ;
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var parser = try Parser.init(allocator, input);
    defer parser.deinit();
    
    _ = parser.parseDocument() catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parse succeeded!\n", .{});
}