const std = @import("std");
const Parser = @import("src/parser.zig").Parser;

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Test case DK95/02: foo: "bar\n  \tbaz"
    const yaml_content = "foo: \"bar\n  \tbaz\"";
    
    std.debug.print("Testing DK95/02 input:\n", .{});
    std.debug.print("Hex dump: ", .{});
    for (yaml_content) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});
    
    var parser = Parser.init(arena.allocator(), yaml_content) catch |err| {
        std.debug.print("Parser init failed: {any}\n", .{err});
        return;
    };
    const result = parser.parseStream();
    
    if (result) |_| {
        std.debug.print("Result: SUCCESS (should pass)\n", .{});
    } else |err| {
        std.debug.print("Result: ERROR - {any} (should pass)\n", .{err});
    }
}