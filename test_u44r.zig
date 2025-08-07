const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\map:
        \\  key1: "quoted1"
        \\   key2: "bad indentation"
    ;
    
    std.debug.print("Testing U44R:\n{s}\n", .{input});
    
    var result = parser.parse(input) catch |err| {
        std.debug.print("Parser error: {}\n", .{err});
        std.debug.print("This is expected - U44R should fail\n", .{});
        return;
    };
    defer result.deinit();
    
    std.debug.print("Parse successful - this is wrong! U44R should fail\n", .{});
}