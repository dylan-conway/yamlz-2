const std = @import("std");
const parser = @import("src/parser.zig");
const ast = @import("src/ast.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = "- !!str, xxx\n";
    
    std.debug.print("Testing U99R: {s}\n", .{input});
    
    // Create a parser
    var p = try parser.Parser.init(allocator, input);
    defer p.deinit();
    
    // Try to parse
    const doc = p.parseDocument() catch |err| {
        std.debug.print("Parser correctly rejected with error: {}\n", .{err});
        return;
    };
    
    // Print the parsed document
    std.debug.print("ERROR: Parser accepted invalid YAML!\n", .{});
    if (doc.root) |root| {
        printNode(root, 0);
    } else {
        std.debug.print("Document has no root node\n", .{});
    }
}

fn printNode(node: *const ast.Node, indent: usize) void {
    for (0..indent) |_| std.debug.print("  ", .{});
    
    if (node.tag) |tag| {
        std.debug.print("Tag: '{s}' ", .{tag});
    }
    if (node.anchor) |anchor| {
        std.debug.print("Anchor: '{s}' ", .{anchor});
    }
    
    switch (node.type) {
        .scalar => {
            const scalar = node.data.scalar;
            std.debug.print("Scalar: '{s}'\n", .{scalar.value});
        },
        .sequence => {
            std.debug.print("Sequence:\n", .{});
            const seq = node.data.sequence;
            for (seq.items.items) |item| {
                printNode(item, indent + 1);
            }
        },
        .mapping => {
            std.debug.print("Mapping:\n", .{});
            const map = node.data.mapping;
            for (map.pairs.items) |pair| {
                for (0..indent + 1) |_| std.debug.print("  ", .{});
                std.debug.print("Key: ", .{});
                printNode(pair.key, 0);
                for (0..indent + 1) |_| std.debug.print("  ", .{});
                std.debug.print("Value: ", .{});
                printNode(pair.value, 0);
            }
        },
        .alias => {
            std.debug.print("Alias: {s}\n", .{node.data.alias});
        },
    }
}