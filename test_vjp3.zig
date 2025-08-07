const std = @import("std");
const parser = @import("src/parser.zig");

pub fn main() !void {
    // Test VJP3/00
    {
        const input = "k: {\nk\n:\nv\n}\n";
        
        std.debug.print("Testing VJP3/00:\n", .{});
        std.debug.print("Input:\n{s}\n", .{input});
        
        // Try just the flow mapping part
        const flow_only = "{k\n:\nv\n}";
        std.debug.print("\nTesting just flow mapping:\n{s}\n", .{flow_only});
        if (parser.parse(flow_only)) |doc| {
            std.debug.print("Flow-only: Success!\n", .{});
            _ = doc;
        } else |err| {
            std.debug.print("Flow-only error: {}\n", .{err});
        }
        
        if (parser.parse(input)) |doc| {
            std.debug.print("Full: Success! Parsed correctly\n", .{});
            _ = doc;
        } else |err| {
            std.debug.print("Full error: {}\n", .{err});
        }
    }
    
    std.debug.print("\n", .{});
    
    // Test VJP3/01
    {
        const input = "k: {\n k\n :\n v\n }\n";
        
        std.debug.print("Testing VJP3/01:\n", .{});
        std.debug.print("Input:\n{s}\n", .{input});
        
        if (parser.parse(input)) |doc| {
            std.debug.print("Success! Parsed correctly\n", .{});
            _ = doc;
        } else |err| {
            std.debug.print("Error: {}\n", .{err});
        }
    }
}