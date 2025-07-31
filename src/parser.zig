const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const ast = @import("ast.zig");

pub const ParseError = error{
    ExpectedCloseBracket,
    ExpectedCloseBrace,
    ExpectedKey,
    ExpectedColon,
    InvalidHexEscape,
    OutOfMemory,
    EmptyFlowEntry,
    InvalidPlainScalar,
    InvalidIndentation,
    UnexpectedCharacter,
    InvalidFlowMapping,
    InvalidBlockScalar,
    InvalidAlias,
    InvalidAnchor,
    InvalidTag,
    DuplicateKey,
    TabsNotAllowed,
    InvalidDocumentStart,
    InvalidDirective,
    UnexpectedContent,
    DirectiveAfterContent,
    DuplicateYamlDirective,
    UnsupportedYamlVersion,
    UnknownDirective,
    UnterminatedQuotedString,
    ExpectedCommaOrBrace,
    DuplicateAnchor,
    InvalidComment,
};

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    in_flow_context: bool = false,
    has_yaml_directive: bool = false,
    
    pub fn init(allocator: std.mem.Allocator, input: []const u8) Parser {
        return .{
            .lexer = Lexer.init(input),
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }
    
    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }
    
    pub fn parseDocument(self: *Parser) ParseError!ast.Document {
        self.skipWhitespaceAndComments();
        
        // Parse directives
        
        while (!self.lexer.isEOF()) {
            // Check for directive
            if (self.lexer.peek() == '%') {
                self.lexer.advanceChar(); // Skip '%'
                
                // Parse directive name
                const directive_start = self.lexer.pos;
                while (!self.lexer.isEOF() and !Lexer.isWhitespace(self.lexer.peek()) and !Lexer.isLineBreak(self.lexer.peek())) {
                    self.lexer.advanceChar();
                }
                const directive_name = self.lexer.input[directive_start..self.lexer.pos];
                
                if (std.mem.eql(u8, directive_name, "YAML")) {
                    if (self.has_yaml_directive) {
                        return error.DuplicateYamlDirective;
                    }
                    self.has_yaml_directive = true;
                    
                    // Skip whitespace (including tabs) and parse version
                    while (!self.lexer.isEOF() and Lexer.isWhitespace(self.lexer.peek())) {
                        self.lexer.advanceChar();
                    }
                    const version_start = self.lexer.pos;
                    while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and self.lexer.peek() != '#') {
                        self.lexer.advanceChar();
                    }
                    const version = std.mem.trim(u8, self.lexer.input[version_start..self.lexer.pos], " \t");
                    
                    // Support both YAML 1.1 and 1.2
                    if (!std.mem.eql(u8, version, "1.1") and !std.mem.eql(u8, version, "1.2")) {
                        return error.UnsupportedYamlVersion;
                    }
                } else if (std.mem.eql(u8, directive_name, "TAG")) {
                    // Skip TAG directive for now - we don't support custom tags yet
                    self.lexer.skipToEndOfLine();
                } else {
                    // Unknown directive - skip it with a warning (not an error)
                    self.lexer.skipToEndOfLine();
                }
                
                // Skip to end of line
                self.lexer.skipToEndOfLine();
                _ = self.lexer.skipLineBreak();
                self.skipWhitespaceAndComments();
            } else if (self.lexer.match("---")) {
                self.lexer.advance(3);
                self.skipWhitespaceAndComments();
                break;
            } else if (self.lexer.match("...")) {
                // Document end marker without content
                self.lexer.advance(3);
                return ast.Document{
                    .root = null,
                    .allocator = self.arena.allocator(),
                };
            } else {
                // Content starts - parse it and exit the directive loop
                break;
            }
        }
        
        const root = if (self.lexer.isEOF()) null else try self.parseValue(0);
        
        return ast.Document{
            .root = root,
            .allocator = self.arena.allocator(),
        };
    }
    
    fn parseValue(self: *Parser, min_indent: usize) ParseError!?*ast.Node {
        self.skipWhitespaceAndComments();
        
        if (self.lexer.isEOF()) return null;
        
        // Check for anchors and tags
        var anchor: ?[]const u8 = null;
        var tag: ?[]const u8 = null;
        
        while (true) {
            const ch = self.lexer.peek();
            
            if (ch == '&') {
                // Anchor
                self.lexer.advanceChar(); // Skip '&'
                const start = self.lexer.pos;
                while (!self.lexer.isEOF() and Lexer.isAnchorChar(self.lexer.peek())) {
                    self.lexer.advanceChar();
                }
                anchor = self.lexer.input[start..self.lexer.pos];
                self.skipWhitespaceAndComments();
            } else if (ch == '!') {
                // Tag
                self.lexer.advanceChar(); // Skip '!'
                const start = self.lexer.pos;
                
                // Handle verbatim tags !<...>
                if (self.lexer.peek() == '<') {
                    self.lexer.advanceChar(); // Skip '<'
                    while (!self.lexer.isEOF() and self.lexer.peek() != '>') {
                        self.lexer.advanceChar();
                    }
                    if (self.lexer.peek() == '>') {
                        self.lexer.advanceChar();
                    }
                } else {
                    // Handle shorthand tags
                    while (!self.lexer.isEOF() and !Lexer.isWhitespace(self.lexer.peek()) and !Lexer.isFlowIndicator(self.lexer.peek()) and self.lexer.peek() != ':') {
                        self.lexer.advanceChar();
                    }
                }
                
                tag = self.lexer.input[start - 1..self.lexer.pos]; // Include the '!'
                self.skipWhitespaceAndComments();
            } else if (ch == '*') {
                // Alias
                self.lexer.advanceChar(); // Skip '*'
                const start = self.lexer.pos;
                while (!self.lexer.isEOF() and Lexer.isAnchorChar(self.lexer.peek())) {
                    self.lexer.advanceChar();
                }
                const alias_name = self.lexer.input[start..self.lexer.pos];
                
                const node = try self.arena.allocator().create(ast.Node);
                node.* = .{
                    .type = .alias,
                    .data = .{ .alias = alias_name },
                };
                return node;
            } else {
                break;
            }
        }
        
        const ch = self.lexer.peek();
        
        var node: ?*ast.Node = null;
        
        if (ch == '[') {
            node = try self.parseFlowSequence();
        } else if (ch == '{') {
            node = try self.parseFlowMapping();
        } else if (ch == '"') {
            node = try self.parseDoubleQuotedScalar();
        } else if (ch == '\'') {
            node = try self.parseSingleQuotedScalar();
        } else if (ch == '|') {
            node = try self.parseLiteralScalar();
        } else if (ch == '>') {
            node = try self.parseFoldedScalar();
        } else {
            const current_column = self.lexer.column;
            if (current_column < min_indent) return null;
            
            if (ch == '-' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\t' or self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or self.lexer.peekNext() == 0)) {
                node = try self.parseBlockSequence(min_indent);
            } else if (ch == '?' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\t' or self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or self.lexer.peekNext() == 0)) {
                // Explicit key starts a block mapping
                node = try self.parseBlockMapping(min_indent);
            } else if (self.isPlainScalarStart(ch)) {
                // In flow context, don't try to detect block mappings
                if (self.in_flow_context) {
                    node = try self.parsePlainScalar();
                } else {
                    const save_pos = self.lexer.pos;
                    const save_line = self.lexer.line;
                    const save_column = self.lexer.column;
                    
                    const scalar = try self.parsePlainScalar();
                    self.skipSpaces();
                    
                    if (self.lexer.peek() == ':' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or self.lexer.peekNext() == 0)) {
                        self.lexer.pos = save_pos;
                        self.lexer.line = save_line;
                        self.lexer.column = save_column;
                        self.arena.allocator().destroy(scalar);
                        node = try self.parseBlockMapping(min_indent);
                    } else {
                        node = scalar;
                        
                        // Check for multi-line implicit key situation in block context
                        // This can happen even at root level (min_indent = 0)
                        const saved_pos = self.lexer.pos;
                        self.skipWhitespaceAndComments();
                        
                        if (!self.lexer.isEOF()) {
                            const next_indent = self.getCurrentIndent();
                            // If next line is at same indent as this scalar
                            if (next_indent == current_column) {
                                // Check for mapping indicator
                                var scan_pos = self.lexer.pos;
                                while (scan_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[scan_pos])) {
                                    if (self.lexer.input[scan_pos] == ':' and
                                        (scan_pos + 1 >= self.lexer.input.len or
                                         self.lexer.input[scan_pos + 1] == ' ' or
                                         Lexer.isLineBreak(self.lexer.input[scan_pos + 1]))) {
                                        // Multi-line implicit key detected
                                        return error.InvalidPlainScalar;
                                    }
                                    scan_pos += 1;
                                }
                            }
                        }
                        
                        self.lexer.pos = saved_pos;
                    }
                }
            } else {
                node = try self.parsePlainScalar();
            }
        }
        
        // Apply anchor and tag if present
        if (node) |n| {
            if (anchor) |a| {
                n.anchor = a;
            }
            if (tag) |t| {
                n.tag = t;
            }
        }
        
        return node;
    }
    
    fn parsePlainScalar(self: *Parser) ParseError!*ast.Node {
        const start_pos = self.lexer.pos;
        var end_pos = start_pos;
        const initial_indent = self.lexer.column;
        
        // std.debug.print("Debug parsePlainScalar: start_pos={}, initial_indent={}, in_flow={}\n", .{start_pos, initial_indent, self.in_flow_context});
        
        // First, consume the first line
        while (!self.lexer.isEOF()) {
            const ch = self.lexer.peek();
            
            if (Lexer.isLineBreak(ch)) break;
            
            // Handle ':' - it ends the scalar in certain contexts
            if (ch == ':') {
                const next = self.lexer.peekNext();
                // Break if: next is whitespace/newline/EOF OR (in flow context AND next is flow indicator)
                if (Lexer.isWhitespace(next) or Lexer.isLineBreak(next) or next == 0 or 
                    (self.in_flow_context and Lexer.isFlowIndicator(next))) {
                    break;
                }
            }
            
            if (ch == '#' and (self.lexer.pos == 0 or self.lexer.input[self.lexer.pos - 1] == ' ')) break;
            // In flow context, flow indicators end the scalar
            if (self.in_flow_context and Lexer.isFlowIndicator(ch)) break;
            
            self.lexer.advanceChar();
            if (!Lexer.isWhitespace(ch)) {
                end_pos = self.lexer.pos;
            }
        }
        
        // Now handle potential multi-line scalars
        if (!self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek())) {
            var first_continuation_indent: ?usize = null;
            
            // Debug - removed
            
            while (!self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek())) {
                const line_break_pos = self.lexer.pos;
                self.lexer.advanceChar(); // Skip line break
                
                // Skip spaces on new line - but track if we encounter tabs for indentation
                var spaces_count: usize = 0;
                while (self.lexer.peek() == ' ') {
                    self.lexer.advanceChar();
                    spaces_count += 1;
                }
                // Tabs used as indentation (before any content) are not allowed
                if (self.lexer.peek() == '\t' and spaces_count == 0) {
                    return error.TabsNotAllowed;
                }
                const new_indent = self.lexer.column;
                
                // Check if this line starts with a comment
                if (self.lexer.peek() == '#') {
                    // Comment interrupts the plain scalar
                    // Check if there's more content after the comment
                    self.lexer.skipToEndOfLine();
                    if (!self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek())) {
                        self.lexer.advanceChar(); // Skip line break
                        self.skipSpaces();
                        const after_comment_indent = self.lexer.column;
                        
                        // If there's content after the comment at the same or less indentation
                        // as the initial key, this creates an invalid multi-line implicit key
                        if (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and 
                            after_comment_indent <= initial_indent) {
                            return error.InvalidPlainScalar;
                        }
                    }
                    
                    // Restore position to before the comment
                    self.lexer.pos = line_break_pos;
                    break;
                }
                
                // Check what's on this line
                if (self.lexer.isEOF() or Lexer.isLineBreak(self.lexer.peek())) {
                    // Empty line - continue
                    continue;
                }
                
                // For continuation, line must be more indented than the key
                if (new_indent <= initial_indent) {
                    // std.debug.print("Debug plain scalar: Line at indent {} <= initial {}, stopping\n", .{new_indent, initial_indent});
                    // Not a continuation - restore position to before line break
                    self.lexer.pos = line_break_pos;
                    break;
                }
                
                // std.debug.print("Debug plain scalar: Continuing line at indent {}\n", .{new_indent});
                
                // If this is the first continuation line, remember its indent
                if (first_continuation_indent == null) {
                    first_continuation_indent = new_indent;
                }
                
                // This line is part of the scalar - consume it
                // But first check if this line contains a mapping indicator
                // which would make this an invalid multi-line implicit key
                var scan_pos = self.lexer.pos;
                while (scan_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[scan_pos])) {
                    if (self.lexer.input[scan_pos] == ':' and
                        (scan_pos + 1 >= self.lexer.input.len or
                         self.lexer.input[scan_pos + 1] == ' ' or
                         Lexer.isLineBreak(self.lexer.input[scan_pos + 1]))) {
                        // std.debug.print("Debug HU3P: Found ':' in continuation line, multiline implicit key error\n", .{});
                        // This creates a multi-line implicit key
                        return error.InvalidPlainScalar;
                    }
                    scan_pos += 1;
                }
                
                // Now consume the line
                while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                    const ch = self.lexer.peek();
                    if (ch == '#' and self.lexer.input[self.lexer.pos - 1] == ' ') break;
                    
                    
                    self.lexer.advanceChar();
                    if (!Lexer.isWhitespace(ch)) {
                        end_pos = self.lexer.pos;
                    }
                }
            }
        }
        
        var value = self.lexer.input[start_pos..end_pos];
        
        // std.debug.print("Debug parsePlainScalar: parsed '{s}' from pos {} to {}\n", .{value, start_pos, end_pos});
        
        // Check for special values and convert to canonical form
        if (std.mem.eql(u8, value, "null") or std.mem.eql(u8, value, "Null") or std.mem.eql(u8, value, "NULL") or
            std.mem.eql(u8, value, "~") or std.mem.eql(u8, value, "")) {
            value = "null";
        } else if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "True") or std.mem.eql(u8, value, "TRUE") or
                   std.mem.eql(u8, value, "yes") or std.mem.eql(u8, value, "Yes") or std.mem.eql(u8, value, "YES") or
                   std.mem.eql(u8, value, "on") or std.mem.eql(u8, value, "On") or std.mem.eql(u8, value, "ON") or
                   std.mem.eql(u8, value, "y") or std.mem.eql(u8, value, "Y")) {
            value = "true";
        } else if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "False") or std.mem.eql(u8, value, "FALSE") or
                   std.mem.eql(u8, value, "no") or std.mem.eql(u8, value, "No") or std.mem.eql(u8, value, "NO") or
                   std.mem.eql(u8, value, "off") or std.mem.eql(u8, value, "Off") or std.mem.eql(u8, value, "OFF") or
                   std.mem.eql(u8, value, "n") or std.mem.eql(u8, value, "N")) {
            value = "false";
        } else if (std.mem.eql(u8, value, ".inf") or std.mem.eql(u8, value, ".Inf") or std.mem.eql(u8, value, ".INF") or
                   std.mem.eql(u8, value, "+.inf") or std.mem.eql(u8, value, "+.Inf") or std.mem.eql(u8, value, "+.INF")) {
            value = ".inf";
        } else if (std.mem.eql(u8, value, "-.inf") or std.mem.eql(u8, value, "-.Inf") or std.mem.eql(u8, value, "-.INF")) {
            value = "-.inf";
        } else if (std.mem.eql(u8, value, ".nan") or std.mem.eql(u8, value, ".NaN") or std.mem.eql(u8, value, ".NAN")) {
            value = ".nan";
        }
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .scalar,
            .data = .{ .scalar = .{ .value = value, .style = .plain } },
        };
        
        return node;
    }
    
    fn parseFlowSequence(self: *Parser) ParseError!*ast.Node {
        self.lexer.advanceChar(); // Skip '['
        const saved_flow_context = self.in_flow_context;
        self.in_flow_context = true;
        defer self.in_flow_context = saved_flow_context;
        
        try self.skipWhitespaceAndCommentsInFlow();
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .sequence,
            .data = .{ .sequence = .{ .items = std.ArrayList(*ast.Node).init(self.arena.allocator()) } },
        };
        
        var first_item = true;
        
        while (!self.lexer.isEOF() and self.lexer.peek() != ']') {
            // Handle empty entries
            if (self.lexer.peek() == ',') {
                if (first_item) {
                    // Leading comma not allowed
                    return error.EmptyFlowEntry;
                }
                // Check for consecutive commas (empty entry)
                self.lexer.advanceChar();
                try self.skipWhitespaceAndCommentsInFlow();
                if (self.lexer.peek() == ',') {
                    // Empty entry not allowed (consecutive commas)
                    return error.EmptyFlowEntry;
                }
                // Trailing comma before ] is allowed in YAML 1.2
                continue;
            }
            
            // Check if this is a mapping with empty key
            if (self.lexer.peek() == ':') {
                // Empty key mapping
                self.lexer.advanceChar(); // Skip ':'
                try self.skipWhitespaceAndCommentsInFlow();
                
                const map_value = try self.parseValue(0) orelse try self.createNullNode();
                
                // Create a mapping with single pair (null key)
                const map_node = try self.arena.allocator().create(ast.Node);
                map_node.* = .{
                    .type = .mapping,
                    .data = .{ .mapping = .{ .pairs = std.ArrayList(ast.Pair).init(self.arena.allocator()) } },
                };
                const null_key = try self.createNullNode();
                try map_node.data.mapping.pairs.append(.{ .key = null_key, .value = map_value });
                try node.data.sequence.items.append(map_node);
                first_item = false;
            } else {
                // Parse item
                const item = try self.parseValue(0);
                if (item) |value| {
                    try self.skipWhitespaceAndCommentsInFlow();
                    
                    // Check if this is a mapping key
                    if (self.lexer.peek() == ':') {
                        // This is a single-pair mapping
                        self.lexer.advanceChar(); // Skip ':'
                        try self.skipWhitespaceAndCommentsInFlow();
                        
                        const map_value = try self.parseValue(0) orelse try self.createNullNode();
                        
                        // Create a mapping with single pair
                        const map_node = try self.arena.allocator().create(ast.Node);
                        map_node.* = .{
                            .type = .mapping,
                            .data = .{ .mapping = .{ .pairs = std.ArrayList(ast.Pair).init(self.arena.allocator()) } },
                        };
                        try map_node.data.mapping.pairs.append(.{ .key = value, .value = map_value });
                        try node.data.sequence.items.append(map_node);
                    } else {
                        try node.data.sequence.items.append(value);
                    }
                    first_item = false;
                }
            }
            
            try self.skipWhitespaceAndCommentsInFlow();
            
            // Don't consume trailing comma yet
        }
        
        // Trailing comma is allowed in YAML 1.2 flow sequences
        
        if (self.lexer.peek() == ']') {
            self.lexer.advanceChar();
            // Check for comment immediately after closing bracket
            if (!self.lexer.isEOF() and self.lexer.peek() == '#') {
                return error.InvalidComment;
            }
        } else {
            return error.ExpectedCloseBracket;
        }
        
        return node;
    }
    
    fn parseFlowMapping(self: *Parser) ParseError!*ast.Node {
        self.lexer.advanceChar(); // Skip '{'
        const saved_flow_context = self.in_flow_context;
        self.in_flow_context = true;
        defer self.in_flow_context = saved_flow_context;
        
        try self.skipWhitespaceAndCommentsInFlow();
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .mapping,
            .data = .{ .mapping = .{ .pairs = std.ArrayList(ast.Pair).init(self.arena.allocator()) } },
        };
        
        while (!self.lexer.isEOF() and self.lexer.peek() != '}') {
            // std.debug.print("Debug: Flow mapping loop, pos={}, char='{}' (0x{x})\n", .{self.lexer.pos, self.lexer.peek(), self.lexer.peek()});
            if (self.lexer.peek() == ',') {
                self.lexer.advanceChar();
                try self.skipWhitespaceAndCommentsInFlow();
                // Check for trailing comma
                if (self.lexer.peek() == '}') {
                    break;
                }
                continue;
            }
            
            var key: ?*ast.Node = null;
            
            // Check for empty key
            if (self.lexer.peek() == ':') {
                key = try self.createNullNode();
            } else if (self.lexer.peek() == '?') {
                // Explicit key indicator
                self.lexer.advanceChar(); // Skip '?'
                try self.skipSpacesCheckTabs();
                try self.skipWhitespaceAndCommentsInFlow();
                key = try self.parseValue(0) orelse try self.createNullNode();
                try self.skipWhitespaceAndCommentsInFlow();
            } else {
                key = try self.parseValue(0) orelse return error.ExpectedKey;
            }
            
            try self.skipWhitespaceAndCommentsInFlow();
            
            if (self.lexer.peek() != ':') {
                return error.ExpectedColon;
            }
            self.lexer.advanceChar();
            
            try self.skipWhitespaceAndCommentsInFlow();
            
            // std.debug.print("Debug: After parsing key and colon, pos={}, char='{}' (0x{x})\n", .{self.lexer.pos, self.lexer.peek(), self.lexer.peek()});
            
            // Handle empty value before comma or closing brace
            var value: *ast.Node = undefined;
            if (self.lexer.peek() == ',' or self.lexer.peek() == '}') {
                value = try self.createNullNode();
            } else {
                value = try self.parseValue(0) orelse try self.createNullNode();
            }
            
            // std.debug.print("Debug: After parsing value, pos={}, char='{}' (0x{x})\n", .{self.lexer.pos, self.lexer.peek(), self.lexer.peek()});
            
            try node.data.mapping.pairs.append(.{ .key = key.?, .value = value });
            
            try self.skipWhitespaceAndCommentsInFlow();
            
            // Check if we've reached the end of the mapping
            if (self.lexer.peek() == '}') {
                // std.debug.print("Debug: Found closing brace, breaking\n", .{});
                break;
            }
            
            if (self.lexer.peek() == ',') {
                self.lexer.advanceChar();
                try self.skipWhitespaceAndCommentsInFlow();
            } else {
                // No comma and not closing brace - error
                return error.ExpectedCommaOrBrace;
            }
        }
        
        if (self.lexer.peek() == '}') {
            self.lexer.advanceChar();
            // Check for comment immediately after closing brace
            if (!self.lexer.isEOF() and self.lexer.peek() == '#') {
                return error.InvalidComment;
            }
        } else {
            return error.ExpectedCloseBrace;
        }
        
        return node;
    }
    
    fn parseBlockSequence(self: *Parser, min_indent: usize) ParseError!*ast.Node {
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .sequence,
            .data = .{ .sequence = .{ .items = std.ArrayList(*ast.Node).init(self.arena.allocator()) } },
        };
        
        var sequence_indent: ?usize = null;
        
        while (!self.lexer.isEOF()) {
            const current_indent = self.getCurrentIndent();
            if (current_indent < min_indent) break;
            
            // If this is not the first item, check that it's at the same indent
            if (sequence_indent) |seq_indent| {
                if (current_indent != seq_indent) break;
            } else {
                // First item - remember its indent
                sequence_indent = current_indent;
            }
            
            if (self.lexer.peek() == '-' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\t' or self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or self.lexer.peekNext() == 0)) {
                // Before processing a new sequence item, check for tabs in its indentation
                try self.checkIndentationForTabs();
                
                self.lexer.advanceChar(); // Skip '-'
                
                // Skip spaces after '-'
                if (self.lexer.peek() == ' ') {
                    self.skipSpaces();
                }
                
                const item = try self.parseValue(current_indent + 1) orelse try self.createNullNode();
                try node.data.sequence.items.append(item);
                
                self.skipToNextLine();
            } else {
                break;
            }
        }
        
        return node;
    }
    
    fn parseBlockMapping(self: *Parser, min_indent: usize) ParseError!*ast.Node {
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .mapping,
            .data = .{ .mapping = .{ .pairs = std.ArrayList(ast.Pair).init(self.arena.allocator()) } },
        };
        
        var mapping_indent: ?usize = null;
        var pending_explicit_key: ?*ast.Node = null;
        
        while (!self.lexer.isEOF()) {
            const current_indent = self.getCurrentIndent();
            if (current_indent < min_indent) break;
            
            // If this is not the first pair, check that it's at the same indent
            if (mapping_indent) |map_indent| {
                if (current_indent != map_indent) break;
            } else {
                // First pair - remember its indent
                mapping_indent = current_indent;
            }
            
            var key: ?*ast.Node = null;
            
            // Check if we have a pending explicit key waiting for its colon
            if (pending_explicit_key) |pkey| {
                if (self.lexer.peek() == ':') {
                    key = pkey;
                    pending_explicit_key = null;
                    self.lexer.advanceChar(); // Skip ':'
                } else {
                    // Expected colon after explicit key
                    return error.ExpectedColon;
                }
            } else {
                // Before processing a new mapping pair, check for tabs in its indentation
                try self.checkIndentationForTabs();
                
                // Check for explicit key indicator
                if (self.lexer.peek() == '?' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\t' or 
                                                   self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or 
                                                   self.lexer.peekNext() == 0)) {
                    // Explicit key
                    self.lexer.advanceChar(); // Skip '?'
                    try self.skipSpacesCheckTabs();
                    self.skipWhitespaceAndComments();
                    
                    // Parse the key
                    const key_indent = self.getCurrentIndent();
                    key = try self.parseValue(key_indent) orelse try self.createNullNode();
                    
                    // Skip to colon - it might be on a new line
                    self.skipWhitespaceAndComments();
                    
                    
                    // For explicit keys, the colon might be on the next line
                    // Store the key and continue to find the colon
                    pending_explicit_key = key;
                    continue;
                } else {
                    // Implicit key
                    key = try self.parsePlainScalar();
                    self.skipSpaces();
                    
                    if (self.lexer.peek() != ':') {
                        self.arena.allocator().destroy(key.?);
                        break;
                    }
                    self.lexer.advanceChar();
                }
            }
            
            if (self.lexer.peek() == ' ' or Lexer.isLineBreak(self.lexer.peek())) {
                try self.skipSpacesCheckTabs();
                
                var value: ?*ast.Node = null;
                
                if (Lexer.isLineBreak(self.lexer.peek()) or self.lexer.isEOF()) {
                    self.skipToNextLine();
                    const value_indent = self.getCurrentIndent();
                    if (value_indent > current_indent) {
                        value = try self.parseValue(value_indent);
                    }
                } else {
                    value = try self.parseValue(current_indent);
                    
                    // Debug output for HU3P
                    // if (value != null and value.?.type == .scalar) {
                    //     std.debug.print("Debug HU3P: Parsed value as scalar, style={}, value='{s}'\n", 
                    //         .{value.?.data.scalar.style, value.?.data.scalar.value});
                    // }
                    
                    // After parsing a plain scalar value, check if the next line at the same
                    // indentation as the value contains a mapping indicator, which would
                    // create an invalid multi-line implicit key
                    if (value != null and value.?.type == .scalar and value.?.data.scalar.style == .plain) {
                        const saved_pos = self.lexer.pos;
                        self.skipWhitespaceAndComments();
                        
                        if (!self.lexer.isEOF()) {
                            const next_line_indent = self.getCurrentIndent();
                            // std.debug.print("Debug HU3P: next_line_indent={}, current_indent={}\n", 
                            //     .{next_line_indent, current_indent});
                            
                            // The value was parsed starting from after the spaces following the colon
                            // We need to check if the next line is at the same indentation as where
                            // the value started (which would be current_indent + some spaces)
                            // For HU3P: "key:" is at indent 0, value "word1 word2" starts at column 3
                            // and "no: key" is also at column 3
                            if (next_line_indent > current_indent) {
                                // Check for mapping indicator
                                var scan_pos = self.lexer.pos;
                                // std.debug.print("Debug HU3P: Scanning for ':' starting at pos {}\n", .{scan_pos});
                                while (scan_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[scan_pos])) {
                                    if (self.lexer.input[scan_pos] == ':' and
                                        (scan_pos + 1 >= self.lexer.input.len or
                                         self.lexer.input[scan_pos + 1] == ' ' or
                                         Lexer.isLineBreak(self.lexer.input[scan_pos + 1]))) {
                                        // std.debug.print("Debug HU3P: Found ':' at pos {}, this is a multiline implicit key error!\n", .{scan_pos});
                                        // This creates a multi-line implicit key
                                        return error.InvalidPlainScalar;
                                    }
                                    scan_pos += 1;
                                }
                            }
                        }
                        
                        self.lexer.pos = saved_pos;
                    }
                }
                
                if (value == null) {
                    value = try self.createNullNode();
                }
                
                try node.data.mapping.pairs.append(.{ .key = key.?, .value = value.? });
                
                // std.debug.print("Debug HU3P: Added mapping pair, about to skip to next line\n", .{});
                
                // Always skip to the next line after parsing a mapping pair
                if (!self.lexer.isEOF()) {
                    self.skipToNextLine();
                    // std.debug.print("Debug HU3P: After skipToNextLine, pos={}, line={}, col={}\n", 
                    //     .{self.lexer.pos, self.lexer.line, self.lexer.column});
                }
            } else {
                if (key) |k| {
                    self.arena.allocator().destroy(k);
                }
                break;
            }
        }
        
        return node;
    }
    
    fn parseSingleQuotedScalar(self: *Parser) ParseError!*ast.Node {
        self.lexer.advanceChar(); // Skip opening quote
        
        var result = std.ArrayList(u8).init(self.arena.allocator());
        
        while (!self.lexer.isEOF()) {
            const ch = self.lexer.peek();
            
            if (ch == '\'') {
                if (self.lexer.peekNext() == '\'') {
                    try result.append('\'');
                    self.lexer.advance(2);
                } else {
                    self.lexer.advanceChar();
                    break;
                }
            } else {
                try result.append(ch);
                self.lexer.advanceChar();
            }
        }
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .scalar,
            .data = .{ .scalar = .{ .value = result.items, .style = .single_quoted } },
        };
        
        return node;
    }
    
    fn parseDoubleQuotedScalar(self: *Parser) ParseError!*ast.Node {
        self.lexer.advanceChar(); // Skip opening quote
        
        var result = std.ArrayList(u8).init(self.arena.allocator());
        var found_closing_quote = false;
        
        while (!self.lexer.isEOF()) {
            const ch = self.lexer.peek();
            
            if (ch == '"') {
                self.lexer.advanceChar();
                found_closing_quote = true;
                break;
            } else if (ch == '\\') {
                self.lexer.advanceChar();
                if (self.lexer.isEOF()) break;
                
                const escaped = self.lexer.peek();
                self.lexer.advanceChar();
                
                switch (escaped) {
                    '0' => try result.append('\x00'),
                    'a' => try result.append('\x07'),
                    'b' => try result.append('\x08'),
                    't', '\t' => try result.append('\t'),
                    'n' => try result.append('\n'),
                    'v' => try result.append('\x0B'),
                    'f' => try result.append('\x0C'),
                    'r' => try result.append('\r'),
                    'e' => try result.append('\x1B'),
                    ' ' => try result.append(' '),
                    '"' => try result.append('"'),
                    '/' => try result.append('/'),
                    '\\' => try result.append('\\'),
                    'N' => {
                        // Unicode NEL (Next Line) U+0085
                        try result.append(0xC2);
                        try result.append(0x85);
                    },
                    '_' => {
                        // Unicode NBSP (Non-breaking space) U+00A0
                        try result.append(0xC2);
                        try result.append(0xA0);
                    },
                    'L' => {
                        // Unicode LS (Line Separator) U+2028
                        try result.append(0xE2);
                        try result.append(0x80);
                        try result.append(0xA8);
                    },
                    'P' => {
                        // Unicode PS (Paragraph Separator) U+2029
                        try result.append(0xE2);
                        try result.append(0x80);
                        try result.append(0xA9);
                    },
                    'x' => {
                        const hex1 = self.lexer.peek();
                        self.lexer.advanceChar();
                        const hex2 = self.lexer.peek();
                        self.lexer.advanceChar();
                        
                        if (Lexer.isHex(hex1) and Lexer.isHex(hex2)) {
                            const value = (hexValue(hex1) << 4) | hexValue(hex2);
                            try result.append(@as(u8, @intCast(value)));
                        } else {
                            return error.InvalidHexEscape;
                        }
                    },
                    '\n' => {
                        // Escaped newline - skip the newline and any following whitespace
                        while (!self.lexer.isEOF() and (self.lexer.peek() == ' ' or self.lexer.peek() == '\t')) {
                            self.lexer.advanceChar();
                        }
                    },
                    '\r' => {
                        // Escaped CRLF
                        if (self.lexer.peek() == '\n') {
                            self.lexer.advanceChar();
                        }
                        // Skip any following whitespace
                        while (!self.lexer.isEOF() and (self.lexer.peek() == ' ' or self.lexer.peek() == '\t')) {
                            self.lexer.advanceChar();
                        }
                    },
                    else => try result.append(escaped),
                }
            } else if (ch == '\n' or ch == '\r') {
                // Handle line folding in double-quoted strings
                self.lexer.advanceChar();
                if (ch == '\r' and self.lexer.peek() == '\n') {
                    self.lexer.advanceChar();
                }
                
                // Check if the next line starts with a tab (which is not allowed as indentation)
                const line_start_pos = self.lexer.pos;
                var found_tab_at_start = false;
                while (!self.lexer.isEOF() and (self.lexer.peek() == ' ' or self.lexer.peek() == '\t')) {
                    if (self.lexer.pos == line_start_pos and self.lexer.peek() == '\t') {
                        found_tab_at_start = true;
                    }
                    self.lexer.advanceChar();
                }
                
                if (found_tab_at_start) {
                    return error.TabsNotAllowed;
                }
                
                // Reset to start of line and skip leading whitespace properly
                self.lexer.pos = line_start_pos;
                var has_content = false;
                while (!self.lexer.isEOF()) {
                    const next_ch = self.lexer.peek();
                    if (next_ch == ' ' or next_ch == '\t') {
                        self.lexer.advanceChar();
                    } else if (next_ch == '\n' or next_ch == '\r') {
                        // Empty line - append newline to result
                        try result.append('\n');
                        self.lexer.advanceChar();
                        if (next_ch == '\r' and self.lexer.peek() == '\n') {
                            self.lexer.advanceChar();
                        }
                    } else {
                        has_content = true;
                        break;
                    }
                }
                
                // If we have content after the newline, fold it into a space
                if (has_content and result.items.len > 0) {
                    try result.append(' ');
                }
            } else if (ch == ' ' or ch == '\t') {
                // Handle trailing whitespace before newlines
                const ws_start = self.lexer.pos;
                while (!self.lexer.isEOF() and (self.lexer.peek() == ' ' or self.lexer.peek() == '\t')) {
                    self.lexer.advanceChar();
                }
                
                // If followed by newline, don't include the whitespace
                if (!self.lexer.isEOF() and (self.lexer.peek() == '\n' or self.lexer.peek() == '\r')) {
                    // Skip the whitespace
                } else {
                    // Include the whitespace
                    const ws_end = self.lexer.pos;
                    try result.appendSlice(self.lexer.input[ws_start..ws_end]);
                }
            } else {
                try result.append(ch);
                self.lexer.advanceChar();
            }
        }
        
        if (!found_closing_quote) {
            return error.UnterminatedQuotedString;
        }
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .scalar,
            .data = .{ .scalar = .{ .value = result.items, .style = .double_quoted } },
        };
        
        return node;
    }
    
    fn createNullNode(self: *Parser) ParseError!*ast.Node {
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .scalar,
            .data = .{ .scalar = .{ .value = "null", .style = .plain } },
        };
        return node;
    }
    
    fn parseLiteralScalar(self: *Parser) ParseError!*ast.Node {
        self.lexer.advanceChar(); // Skip '|'
        
        // Handle block scalar indicators
        var chomp_indicator: enum { clip, strip, keep } = .clip;
        var explicit_indent: ?usize = null;
        
        // Block scalar indicators can come in either order: chomp then indent or indent then chomp
        var ch = self.lexer.peek();
        
        // First, check for indent indicator (digit)
        if (Lexer.isDecimal(ch)) {
            explicit_indent = @as(usize, ch - '0');
            self.lexer.advanceChar();
            ch = self.lexer.peek();
        }
        
        // Then check for chomp indicator
        if (ch == '-') {
            chomp_indicator = .strip;
            self.lexer.advanceChar();
        } else if (ch == '+') {
            chomp_indicator = .keep;
            self.lexer.advanceChar();
        }
        
        // If we didn't find indent before chomp, check again after chomp
        if (explicit_indent == null and Lexer.isDecimal(self.lexer.peek())) {
            explicit_indent = @as(usize, self.lexer.peek() - '0');
            self.lexer.advanceChar();
        }
        
        // After indicators, only whitespace and comments are allowed
        // Tabs are not allowed after block scalar indicators
        try self.skipSpacesCheckTabs();
        if (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and self.lexer.peek() != '#') {
            // Invalid text after block scalar indicator
            return error.InvalidBlockScalar;
        }
        
        // Skip to end of indicator line
        self.lexer.skipToEndOfLine();
        _ = self.lexer.skipLineBreak();
        
        // Determine block indent
        const block_indent = if (explicit_indent) |indent|
            self.getCurrentIndent() + indent
        else blk: {
            // Auto-detect indent
            const current_pos = self.lexer.pos;
            while (!self.lexer.isEOF() and (self.lexer.peek() == ' ' or Lexer.isLineBreak(self.lexer.peek()))) {
                if (self.lexer.peek() == ' ') {
                    self.lexer.advanceChar();
                } else {
                    _ = self.lexer.skipLineBreak();
                }
            }
            const detected_indent = self.getCurrentIndent();
            self.lexer.pos = current_pos;
            break :blk detected_indent;
        };
        
        var result = std.ArrayList(u8).init(self.arena.allocator());
        var had_content = false;
        var trailing_breaks: usize = 0;
        
        while (!self.lexer.isEOF()) {
            const line_indent = self.getCurrentIndent();
            
            // Check if we're done
            if (line_indent < block_indent and !Lexer.isLineBreak(self.lexer.peek()) and self.lexer.peek() != ' ') {
                break;
            }
            
            // Handle empty lines
            if (Lexer.isLineBreak(self.lexer.peek()) or self.lexer.isEOF()) {
                trailing_breaks += 1;
                _ = self.lexer.skipLineBreak();
                continue;
            }
            
            // Skip indent
            if (line_indent >= block_indent) {
                var i: usize = 0;
                while (i < block_indent) : (i += 1) {
                    if (self.lexer.peek() == ' ') self.lexer.advanceChar();
                }
                
                // Add trailing breaks if we had content
                if (had_content) {
                    var j: usize = 0;
                    while (j < trailing_breaks) : (j += 1) {
                        try result.append('\n');
                    }
                }
                trailing_breaks = 0;
                had_content = true;
                
                // Copy line content preserving extra indentation
                const extra_indent = line_indent - block_indent;
                var k: usize = 0;
                while (k < extra_indent) : (k += 1) {
                    try result.append(' ');
                }
                
                // Check if line contains only tabs (invalid)
                var line_has_only_tabs = true;
                const line_start = self.lexer.pos;
                
                while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                    const char = self.lexer.peek();
                    if (char != '\t') line_has_only_tabs = false;
                    try result.append(char);
                    self.lexer.advanceChar();
                }
                
                // If the line had content and it was only tabs, that's an error
                if (line_has_only_tabs and self.lexer.pos > line_start) {
                    return error.TabsNotAllowed;
                }
                
                trailing_breaks = 1;
                _ = self.lexer.skipLineBreak();
            } else {
                break;
            }
        }
        
        // Apply chomping
        switch (chomp_indicator) {
            .clip => {
                // Keep one trailing newline
                if (had_content and result.items.len > 0) {
                    try result.append('\n');
                }
            },
            .strip => {
                // Remove all trailing newlines (already done)
            },
            .keep => {
                // Keep all trailing newlines
                var i: usize = 0;
                while (i < trailing_breaks) : (i += 1) {
                    try result.append('\n');
                }
            },
        }
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .scalar,
            .data = .{ .scalar = .{ .value = result.items, .style = .literal } },
        };
        
        return node;
    }
    
    fn parseFoldedScalar(self: *Parser) ParseError!*ast.Node {
        self.lexer.advanceChar(); // Skip '>'
        
        // Handle block scalar indicators
        var chomp_indicator: enum { clip, strip, keep } = .clip;
        var explicit_indent: ?usize = null;
        
        // Block scalar indicators can come in either order: chomp then indent or indent then chomp
        var ch = self.lexer.peek();
        
        // First, check for indent indicator (digit)
        if (Lexer.isDecimal(ch)) {
            explicit_indent = @as(usize, ch - '0');
            self.lexer.advanceChar();
            ch = self.lexer.peek();
        }
        
        // Then check for chomp indicator
        if (ch == '-') {
            chomp_indicator = .strip;
            self.lexer.advanceChar();
        } else if (ch == '+') {
            chomp_indicator = .keep;
            self.lexer.advanceChar();
        }
        
        // If we didn't find indent before chomp, check again after chomp
        if (explicit_indent == null and Lexer.isDecimal(self.lexer.peek())) {
            explicit_indent = @as(usize, self.lexer.peek() - '0');
            self.lexer.advanceChar();
        }
        
        // After indicators, only whitespace and comments are allowed
        // Tabs are not allowed after block scalar indicators
        try self.skipSpacesCheckTabs();
        if (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and self.lexer.peek() != '#') {
            // Invalid text after block scalar indicator
            return error.InvalidBlockScalar;
        }
        
        // Skip to end of indicator line
        self.lexer.skipToEndOfLine();
        _ = self.lexer.skipLineBreak();
        
        // Determine block indent
        const block_indent = if (explicit_indent) |indent|
            self.getCurrentIndent() + indent
        else blk: {
            // Auto-detect indent
            const current_pos = self.lexer.pos;
            while (!self.lexer.isEOF() and (self.lexer.peek() == ' ' or Lexer.isLineBreak(self.lexer.peek()))) {
                if (self.lexer.peek() == ' ') {
                    self.lexer.advanceChar();
                } else {
                    _ = self.lexer.skipLineBreak();
                }
            }
            const detected_indent = self.getCurrentIndent();
            self.lexer.pos = current_pos;
            break :blk detected_indent;
        };
        
        var result = std.ArrayList(u8).init(self.arena.allocator());
        var had_content = false;
        var trailing_breaks: usize = 0;
        var last_was_empty = false;
        
        while (!self.lexer.isEOF()) {
            const line_indent = self.getCurrentIndent();
            
            // Check if we're done
            if (line_indent < block_indent and !Lexer.isLineBreak(self.lexer.peek()) and self.lexer.peek() != ' ') {
                break;
            }
            
            // Handle empty lines
            if (Lexer.isLineBreak(self.lexer.peek()) or self.lexer.isEOF()) {
                trailing_breaks += 1;
                last_was_empty = true;
                _ = self.lexer.skipLineBreak();
                continue;
            }
            
            // Skip indent
            if (line_indent >= block_indent) {
                var i: usize = 0;
                while (i < block_indent) : (i += 1) {
                    if (self.lexer.peek() == ' ') self.lexer.advanceChar();
                }
                
                // Handle folding
                if (had_content) {
                    if (trailing_breaks == 0) {
                        // No line break - should not happen
                    } else if (trailing_breaks == 1 and !last_was_empty) {
                        // Single line break - fold to space
                        try result.append(' ');
                    } else {
                        // Multiple line breaks or after empty line - preserve as newlines
                        var j: usize = 0;
                        while (j < trailing_breaks - 1) : (j += 1) {
                            try result.append('\n');
                        }
                        if (trailing_breaks > 0 and last_was_empty) {
                            try result.append('\n');
                        }
                    }
                }
                trailing_breaks = 0;
                last_was_empty = false;
                had_content = true;
                
                // Copy line content preserving extra indentation  
                const extra_indent = line_indent - block_indent;
                var k: usize = 0;
                while (k < extra_indent) : (k += 1) {
                    try result.append(' ');
                }
                
                // Check if line contains only tabs (invalid)
                var line_has_only_tabs = true;
                const line_start = self.lexer.pos;
                
                while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                    const char = self.lexer.peek();
                    if (char != '\t') line_has_only_tabs = false;
                    try result.append(char);
                    self.lexer.advanceChar();
                }
                
                // If the line had content and it was only tabs, that's an error
                if (line_has_only_tabs and self.lexer.pos > line_start) {
                    return error.TabsNotAllowed;
                }
                
                trailing_breaks = 1;
                _ = self.lexer.skipLineBreak();
            } else {
                break;
            }
        }
        
        // Apply chomping
        switch (chomp_indicator) {
            .clip => {
                // Keep one trailing newline
                if (had_content and result.items.len > 0) {
                    try result.append('\n');
                }
            },
            .strip => {
                // Remove all trailing newlines (already done)
            },
            .keep => {
                // Keep all trailing newlines
                var i: usize = 0;
                while (i < trailing_breaks) : (i += 1) {
                    try result.append('\n');
                }
            },
        }
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .scalar,
            .data = .{ .scalar = .{ .value = result.items, .style = .folded } },
        };
        
        return node;
    }
    
    fn skipWhitespaceAndComments(self: *Parser) void {
        while (!self.lexer.isEOF()) {
            if (Lexer.isWhitespace(self.lexer.peek())) {
                self.lexer.skipWhitespace();
            } else if (self.lexer.peek() == '#') {
                self.lexer.skipToEndOfLine();
                _ = self.lexer.skipLineBreak();
            } else if (Lexer.isLineBreak(self.lexer.peek())) {
                _ = self.lexer.skipLineBreak();
            } else {
                break;
            }
        }
    }
    
    fn skipWhitespaceAndCommentsInFlow(self: *Parser) ParseError!void {
        while (!self.lexer.isEOF()) {
            // At start of line in flow context, tabs are not allowed as indentation
            // But only if they're followed by content on the same line
            if (self.lexer.column == 1 and self.lexer.peek() == '\t') {
                // Look ahead to see if there's non-whitespace content on this line
                var lookahead = self.lexer.pos + 1;
                while (lookahead < self.lexer.input.len and (self.lexer.input[lookahead] == '\t' or self.lexer.input[lookahead] == ' ')) {
                    lookahead += 1;
                }
                if (lookahead < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[lookahead])) {
                    // Tab is being used as indentation before content
                    return error.TabsNotAllowed;
                }
            }
            
            if (Lexer.isWhitespace(self.lexer.peek())) {
                self.lexer.skipWhitespace();
            } else if (self.lexer.peek() == '#') {
                // Comments must be preceded by whitespace in flow contexts
                if (self.lexer.pos > 0 and !Lexer.isWhitespace(self.lexer.input[self.lexer.pos - 1])) {
                    return error.InvalidComment;
                }
                self.lexer.skipToEndOfLine();
                _ = self.lexer.skipLineBreak();
            } else if (Lexer.isLineBreak(self.lexer.peek())) {
                _ = self.lexer.skipLineBreak();
            } else {
                break;
            }
        }
    }
    
    fn skipWhitespaceAndCommentsCheckTabs(self: *Parser) ParseError!void {
        while (!self.lexer.isEOF()) {
            if (self.lexer.peek() == '\t') {
                return error.TabsNotAllowed;
            } else if (Lexer.isWhitespace(self.lexer.peek())) {
                self.lexer.skipWhitespace();
            } else if (self.lexer.peek() == '#') {
                self.lexer.skipToEndOfLine();
                _ = self.lexer.skipLineBreak();
            } else if (Lexer.isLineBreak(self.lexer.peek())) {
                _ = self.lexer.skipLineBreak();
            } else {
                break;
            }
        }
    }
    
    fn skipSpaces(self: *Parser) void {
        self.lexer.skipSpaces();
    }
    
    fn skipSpacesCheckTabs(self: *Parser) ParseError!void {
        // In many contexts, tabs are not allowed where spaces are expected
        if (self.lexer.peek() == '\t') {
            return error.TabsNotAllowed;
        }
        self.lexer.skipSpaces();
    }
    
    fn skipToNextLine(self: *Parser) void {
        self.lexer.skipToEndOfLine();
        _ = self.lexer.skipLineBreak();
        self.skipWhitespaceAndComments();
    }
    
    fn getCurrentIndent(self: *Parser) usize {
        const save_pos = self.lexer.pos;
        const save_line = self.lexer.line;
        const save_column = self.lexer.column;
        
        self.lexer.pos = self.lexer.line_start;
        self.lexer.column = 1;
        
        var indent: usize = 0;
        while (self.lexer.pos < save_pos) {
            const ch = self.lexer.peek();
            if (ch == ' ') {
                indent += 1;
                self.lexer.advanceChar();
            } else if (ch == '\t') {
                // Tab found in indentation - this is not allowed in YAML
                // We'll still count it to avoid infinite loops, but parsing will fail
                indent += 1;
                self.lexer.advanceChar();
            } else {
                break;
            }
        }
        
        self.lexer.pos = save_pos;
        self.lexer.line = save_line;
        self.lexer.column = save_column;
        
        return indent;
    }
    
    fn checkIndentationForTabs(self: *Parser) ParseError!void {
        const save_pos = self.lexer.pos;
        const save_line = self.lexer.line;
        const save_column = self.lexer.column;
        
        // Don't check empty lines or EOF
        if (self.lexer.isEOF() or Lexer.isLineBreak(self.lexer.peek())) {
            self.lexer.pos = save_pos;
            self.lexer.line = save_line;
            self.lexer.column = save_column;
            return;
        }
        
        self.lexer.pos = self.lexer.line_start;
        self.lexer.column = 1;
        
        // Check for tabs only in the leading whitespace (indentation)
        while (self.lexer.pos < self.lexer.input.len) {
            const ch = self.lexer.peek();
            if (ch == ' ') {
                self.lexer.advanceChar();
            } else if (ch == '\t') {
                // Found a tab in indentation
                self.lexer.pos = save_pos;
                self.lexer.line = save_line;
                self.lexer.column = save_column;
                return error.TabsNotAllowed;
            } else {
                // We've reached non-whitespace, stop checking
                break;
            }
        }
        
        self.lexer.pos = save_pos;
        self.lexer.line = save_line;
        self.lexer.column = save_column;
    }
    
    fn isPlainScalarStart(_: *Parser, ch: u8) bool {
        return Lexer.isSafeFirst(ch) and !Lexer.isWhitespace(ch) and !Lexer.isLineBreak(ch);
    }
    
    fn hexValue(ch: u8) u8 {
        if (ch >= '0' and ch <= '9') return ch - '0';
        if (ch >= 'a' and ch <= 'f') return ch - 'a' + 10;
        if (ch >= 'A' and ch <= 'F') return ch - 'A' + 10;
        return 0;
    }
};

pub fn parse(input: []const u8) ParseError!ast.Document {
    var parser = Parser.init(std.heap.page_allocator, input);
    const doc = try parser.parseDocument();
    // Don't deinit the parser here as it owns the arena
    // The Document will take ownership of the arena allocator
    return doc;
}