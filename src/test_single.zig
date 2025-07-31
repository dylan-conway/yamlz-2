const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("ast.zig");

fn printNode(node: *ast.Node, indent: usize) void {
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        std.debug.print("  ", .{});
    }
    
    switch (node.type) {
        .scalar => {
            std.debug.print("Scalar: '{s}' (style: {})\n", .{node.data.scalar.value, node.data.scalar.style});
        },
        .sequence => {
            std.debug.print("Sequence:\n", .{});
            for (node.data.sequence.items.items) |item| {
                printNode(item, indent + 1);
            }
        },
        .mapping => {
            std.debug.print("Mapping:\n", .{});
            for (node.data.mapping.pairs.items) |pair| {
                i = 0;
                while (i < indent) : (i += 1) {
                    std.debug.print("  ", .{});
                }
                std.debug.print("  Key:\n", .{});
                printNode(pair.key, indent + 2);
                i = 0;
                while (i < indent) : (i += 1) {
                    std.debug.print("  ", .{});
                }
                std.debug.print("  Value:\n", .{});
                printNode(pair.value, indent + 2);
            }
        },
        .alias => {
            std.debug.print("Alias: '{s}'\n", .{node.data.alias});
        },
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.debug.print("Usage: {s} <yaml-file>\n", .{args[0]});
        return;
    }
    
    const file_path = args[1];
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    
    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);
    
    std.debug.print("Testing: {s}\n", .{file_path});
    std.debug.print("Content:\n{s}\n", .{content});
    
    const result = parser.parse(content);
    if (result) |doc| {
        std.debug.print("Result: SUCCESS - Document parsed\n", .{});
        if (doc.root) |root| {
            printNode(root, 0);
        }
    } else |err| {
        std.debug.print("Result: ERROR - {}\n", .{err});
    }
}