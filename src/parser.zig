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
};

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    
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
        
        var has_directives = false;
        
        if (self.lexer.match("---")) {
            self.lexer.advance(3);
            has_directives = true;
            self.skipWhitespaceAndComments();
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
            } else if (self.isPlainScalarStart(ch)) {
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
        const in_block_context = initial_indent > 0; // We're in block context if indented
        
        // First, consume the first line
        while (!self.lexer.isEOF()) {
            const ch = self.lexer.peek();
            
            if (Lexer.isLineBreak(ch)) break;
            if (ch == ':' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or self.lexer.peekNext() == 0)) break;
            if (ch == '#' and (self.lexer.pos == 0 or self.lexer.input[self.lexer.pos - 1] == ' ')) break;
            if (Lexer.isFlowIndicator(ch)) break;
            
            self.lexer.advanceChar();
            if (!Lexer.isWhitespace(ch)) {
                end_pos = self.lexer.pos;
            }
        }
        
        // Now handle potential multi-line scalars
        if (in_block_context and !self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek())) {
            while (!self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek())) {
                const line_break_pos = self.lexer.pos;
                self.lexer.advanceChar(); // Skip line break
                
                // Skip spaces on new line
                self.skipSpaces();
                const new_indent = self.lexer.column;
                
                // Check if this line starts with a comment
                if (self.lexer.peek() == '#') {
                    // Skip the comment line and stop processing multiline scalar
                    self.lexer.pos = line_break_pos;
                    break;
                }
                
                // Check what's on this line
                if (self.lexer.isEOF() or Lexer.isLineBreak(self.lexer.peek())) {
                    // Empty line - continue
                    continue;
                }
                
                // For continuation, line must be more indented
                if (new_indent <= initial_indent) {
                    // Not a continuation - restore position to before line break
                    self.lexer.pos = line_break_pos;
                    break;
                }
                
                // Check for mapping indicator on this line
                var check_pos = self.lexer.pos;
                while (check_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[check_pos])) {
                    if (self.lexer.input[check_pos] == ':') {
                        // Check if it's followed by space/newline/EOF
                        if (check_pos + 1 >= self.lexer.input.len or
                            self.lexer.input[check_pos + 1] == ' ' or
                            Lexer.isLineBreak(self.lexer.input[check_pos + 1])) {
                            // This is a mapping indicator - not allowed in plain scalar
                            return error.InvalidPlainScalar;
                        }
                    }
                    check_pos += 1;
                }
                
                // This line is part of the scalar - consume it
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
        self.skipWhitespaceAndComments();
        
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
                self.skipWhitespaceAndComments();
                if (self.lexer.peek() == ',' or self.lexer.peek() == ']') {
                    // Empty entry not allowed
                    return error.EmptyFlowEntry;
                }
                continue;
            }
            
            // Parse item
            const item = try self.parseValue(0);
            if (item) |value| {
                self.skipWhitespaceAndComments();
                
                // Check if this is a mapping key
                if (self.lexer.peek() == ':') {
                    // This is a single-pair mapping
                    self.lexer.advanceChar(); // Skip ':'
                    self.skipWhitespaceAndComments();
                    
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
            
            self.skipWhitespaceAndComments();
            
            // Don't consume trailing comma yet
        }
        
        // Trailing comma is allowed in YAML 1.2 flow sequences
        
        if (self.lexer.peek() == ']') {
            self.lexer.advanceChar();
        } else {
            return error.ExpectedCloseBracket;
        }
        
        return node;
    }
    
    fn parseFlowMapping(self: *Parser) ParseError!*ast.Node {
        self.lexer.advanceChar(); // Skip '{'
        self.skipWhitespaceAndComments();
        
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .mapping,
            .data = .{ .mapping = .{ .pairs = std.ArrayList(ast.Pair).init(self.arena.allocator()) } },
        };
        
        while (!self.lexer.isEOF() and self.lexer.peek() != '}') {
            if (self.lexer.peek() == ',') {
                self.lexer.advanceChar();
                self.skipWhitespaceAndComments();
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
                self.skipWhitespaceAndComments();
                key = try self.parseValue(0) orelse try self.createNullNode();
                self.skipWhitespaceAndComments();
            } else {
                key = try self.parseValue(0) orelse return error.ExpectedKey;
            }
            
            self.skipWhitespaceAndComments();
            
            if (self.lexer.peek() != ':') {
                return error.ExpectedColon;
            }
            self.lexer.advanceChar();
            
            self.skipWhitespaceAndComments();
            
            // Handle empty value before comma or closing brace
            var value: *ast.Node = undefined;
            if (self.lexer.peek() == ',' or self.lexer.peek() == '}') {
                value = try self.createNullNode();
            } else {
                value = try self.parseValue(0) orelse try self.createNullNode();
            }
            
            try node.data.mapping.pairs.append(.{ .key = key.?, .value = value });
            
            self.skipWhitespaceAndComments();
            
            if (self.lexer.peek() == ',') {
                self.lexer.advanceChar();
                self.skipWhitespaceAndComments();
            }
        }
        
        if (self.lexer.peek() == '}') {
            self.lexer.advanceChar();
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
        
        while (!self.lexer.isEOF()) {
            const current_indent = self.getCurrentIndent();
            if (current_indent < min_indent) break;
            
            if (self.lexer.peek() == '-' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\t' or self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or self.lexer.peekNext() == 0)) {
                self.lexer.advanceChar(); // Skip '-'
                
                // Special handling for tabs after dash
                if (self.lexer.peek() == '\t') {
                    self.lexer.advanceChar(); // Skip tab
                    
                    // Check what follows the tab
                    const after_tab = self.lexer.peek();
                    
                    // Check if it's another block sequence indicator
                    if (after_tab == '-' and self.lexer.pos + 1 < self.lexer.input.len) {
                        const after_dash = self.lexer.peekNext();
                        // -\t- followed by space/tab/newline/eof is invalid
                        if (after_dash == ' ' or after_dash == '\t' or after_dash == '\n' or after_dash == '\r' or after_dash == 0) {
                            return error.TabsNotAllowed;
                        }
                    }
                    // Otherwise continue normally (e.g., -\t-1 is valid)
                } else {
                    try self.skipSpacesCheckTabs();
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
        
        while (!self.lexer.isEOF()) {
            const current_indent = self.getCurrentIndent();
            if (current_indent < min_indent) break;
            
            const key = try self.parsePlainScalar();
            self.skipSpaces();
            
            if (self.lexer.peek() != ':') {
                self.arena.allocator().destroy(key);
                break;
            }
            self.lexer.advanceChar();
            
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
                    
                    // After parsing a plain scalar value, check if the next line at the same
                    // indentation as the value contains a mapping indicator, which would
                    // create an invalid multi-line implicit key
                    if (value != null and value.?.type == .scalar and value.?.data.scalar.style == .plain) {
                        const saved_pos = self.lexer.pos;
                        self.skipWhitespaceAndComments();
                        
                        if (!self.lexer.isEOF()) {
                            const next_line_indent = self.getCurrentIndent();
                            // The value was parsed starting from after the spaces following the colon
                            // We need to check if the next line is at the same indentation as where
                            // the value started (which would be current_indent + some spaces)
                            // For HU3P: "key:" is at indent 0, value "word1 word2" starts at column 3
                            // and "no: key" is also at column 3
                            if (next_line_indent > current_indent) {
                                // Check for mapping indicator
                                var scan_pos = self.lexer.pos;
                                while (scan_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[scan_pos])) {
                                    if (self.lexer.input[scan_pos] == ':' and
                                        (scan_pos + 1 >= self.lexer.input.len or
                                         self.lexer.input[scan_pos + 1] == ' ' or
                                         Lexer.isLineBreak(self.lexer.input[scan_pos + 1]))) {
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
                
                try node.data.mapping.pairs.append(.{ .key = key, .value = value.? });
                
                if (!Lexer.isLineBreak(self.lexer.peek()) and !self.lexer.isEOF()) {
                    self.skipToNextLine();
                }
            } else {
                self.arena.allocator().destroy(key);
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
        
        while (!self.lexer.isEOF()) {
            const ch = self.lexer.peek();
            
            if (ch == '"') {
                self.lexer.advanceChar();
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
                    else => try result.append(escaped),
                }
            } else {
                try result.append(ch);
                self.lexer.advanceChar();
            }
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
                
                while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                    try result.append(self.lexer.peek());
                    self.lexer.advanceChar();
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
                
                while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                    try result.append(self.lexer.peek());
                    self.lexer.advanceChar();
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
        while (self.lexer.pos < save_pos and self.lexer.peek() == ' ') {
            indent += 1;
            self.lexer.advanceChar();
        }
        
        self.lexer.pos = save_pos;
        self.lexer.line = save_line;
        self.lexer.column = save_column;
        
        return indent;
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