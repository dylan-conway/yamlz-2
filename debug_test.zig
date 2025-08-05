const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "foo:\n  bar\ninvalid\n";
    
    std.debug.print("Testing input:\n{s}\n", .{input});
    
    var p = parser.Parser.init(allocator, input);
    defer p.deinit();
    
    const result = p.parseDocument() catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    std.debug.print("Parse succeeded - this should have failed!\n", .{});
    _ = result;
}