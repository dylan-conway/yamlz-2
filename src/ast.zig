const std = @import("std");

pub const NodeType = enum {
    scalar,
    sequence,
    mapping,
    alias,
};

pub const Node = struct {
    type: NodeType,
    start_line: usize = 0,
    start_column: usize = 0,
    anchor: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    
    data: union {
        scalar: Scalar,
        sequence: Sequence,
        mapping: Mapping,
        alias: []const u8,
    },
    
    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self.type) {
            .sequence => self.data.sequence.deinit(allocator),
            .mapping => self.data.mapping.deinit(allocator),
            else => {},
        }
    }
};

pub const Scalar = struct {
    value: []const u8,
    style: enum {
        plain,
        single_quoted,
        double_quoted,
        literal,
        folded,
    } = .plain,
};

pub const Sequence = struct {
    items: std.ArrayList(*Node),
    
    pub fn deinit(self: *Sequence, allocator: std.mem.Allocator) void {
        for (self.items.items) |node| {
            node.deinit(allocator);
            allocator.destroy(node);
        }
        self.items.deinit();
    }
};

pub const Mapping = struct {
    pairs: std.ArrayList(Pair),
    
    pub fn deinit(self: *Mapping, allocator: std.mem.Allocator) void {
        for (self.pairs.items) |pair| {
            pair.key.deinit(allocator);
            allocator.destroy(pair.key);
            pair.value.deinit(allocator);
            allocator.destroy(pair.value);
        }
        self.pairs.deinit();
    }
};

pub const Pair = struct {
    key: *Node,
    value: *Node,
};

pub const Document = struct {
    root: ?*Node = null,
    directives: ?Directives = null,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *Document) void {
        if (self.root) |root| {
            root.deinit(self.allocator);
            self.allocator.destroy(root);
        }
        if (self.directives) |*directives| {
            directives.deinit();
        }
    }
};

pub const Stream = struct {
    documents: std.ArrayList(Document),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Stream {
        return Stream{
            .documents = std.ArrayList(Document).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Stream) void {
        for (self.documents.items) |*doc| {
            doc.deinit();
        }
        self.documents.deinit();
    }
    
    pub fn addDocument(self: *Stream, document: Document) !void {
        try self.documents.append(document);
    }
    
    // For backward compatibility, return the first document if there's only one
    pub fn getSingleDocument(self: *const Stream) ?Document {
        if (self.documents.items.len == 1) {
            return self.documents.items[0];
        }
        return null;
    }
};

pub const Directives = struct {
    yaml_version: ?[]const u8 = null,
    tags: std.ArrayList(TagDirective),
    
    pub fn deinit(self: *Directives) void {
        self.tags.deinit();
    }
};

pub const TagDirective = struct {
    handle: []const u8,
    prefix: []const u8,
};