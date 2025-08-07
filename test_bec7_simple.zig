const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    const input = 
        \\%YAML 1.3 # Attempt parsing
        \\          # with a warning
        \\---
        \\"foo"
    ;

    std.debug.print("Testing BEC7 with YAML 1.3 directive:\n", .{});
    std.debug.print("Input:\n{s}\n", .{input});
    
    const result = parser.parse(input);
    
    if (result) |doc| {
        std.debug.print("Success! Parsed document\n", .{});
        
        // Try to get the value
        if (doc.root) |root| {
            switch (root.type) {
                .scalar => std.debug.print("Got scalar: {s}\n", .{root.data.scalar.value}),
                else => std.debug.print("Got non-scalar content\n", .{}),
            }
        } else {
            std.debug.print("Document has no root\n", .{});
        }
    } else |err| {
        std.debug.print("Error: {}\n", .{err});
    }
}