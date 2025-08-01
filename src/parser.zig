const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const ast = @import("ast.zig");

pub const ParseError = error{
    ExpectedCloseBracket,
    ExpectedCloseBrace,
    ExpectedKey,
    ExpectedColon,
    InvalidHexEscape,
    InvalidEscapeSequence,
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
    ExpectedColonOrComma,
    DuplicateAnchor,
    InvalidComment,
    InvalidDocumentMarker,
};

pub const Parser = struct {
    lexer: Lexer,
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    in_flow_context: bool = false,
    parsing_explicit_key: bool = false,
    has_yaml_directive: bool = false,
    mapping_context_indent: ?usize = null,
    parsing_block_sequence_entry: bool = false,
    
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
                    while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and !Lexer.isWhitespace(self.lexer.peek()) and self.lexer.peek() != '#') {
                        self.lexer.advanceChar();
                    }
                    const version_end = self.lexer.pos;
                    
                    // Check for comment without preceding whitespace
                    if (self.lexer.peek() == '#') {
                        // Comments must be preceded by whitespace
                        return error.InvalidDirective;
                    }
                    
                    // Skip any trailing whitespace before comment or line end
                    while (!self.lexer.isEOF() and Lexer.isWhitespace(self.lexer.peek())) {
                        self.lexer.advanceChar();
                    }
                    
                    const version = self.lexer.input[version_start..version_end];
                    
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
        
        // Check for document markers in flow context - they're not allowed
        if (self.in_flow_context) {
            if (self.lexer.match("---") or self.lexer.match("...")) {
                return error.InvalidDocumentMarker;
            }
        }
        
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
        
        // For multiline scalar validation, we need to know the indent of the containing context
        // not just the scalar content. For mapping values, this is the mapping key's indent + 1.
        const context_indent = if (self.mapping_context_indent) |indent| indent else initial_indent;
        
        // std.debug.print("DEBUG: parsePlainScalar called, char='{c}' (0x{x}), pos={}, indent={}\n", .{self.lexer.peek(), self.lexer.peek(), start_pos, initial_indent});
        
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
                    // Tabs are not allowed as indentation after ':' in block contexts
                    // But they're OK as whitespace when mixed with spaces
                    if (!self.in_flow_context and next == '\t') {
                        // Check what follows the tab - if it's directly non-whitespace, that's invalid indentation
                        var temp_pos = self.lexer.pos + 1; // Skip current char (should be ':')
                        
                        // Look ahead past the tab
                        while (temp_pos < self.lexer.input.len and self.lexer.input[temp_pos] == '\t') {
                            temp_pos += 1;
                        }
                        
                        // If tab is followed directly by non-whitespace (not space), it's invalid indentation
                        if (temp_pos < self.lexer.input.len and 
                            !Lexer.isLineBreak(self.lexer.input[temp_pos]) and
                            self.lexer.input[temp_pos] != ' ') {
                            return error.TabsNotAllowed;
                        }
                    }
                    break;
                }
            }
            
            // Comments must be preceded by whitespace (space or tab) or be at the start of the line
            if (ch == '#' and (self.lexer.pos == 0 or Lexer.isWhitespace(self.lexer.input[self.lexer.pos - 1]))) break;
            // In flow context, flow indicators end the scalar
            if (self.in_flow_context and Lexer.isFlowIndicator(ch)) break;
            
            self.lexer.advanceChar();
            if (!Lexer.isWhitespace(ch)) {
                end_pos = self.lexer.pos;
            }
        }
        
        
        // Now handle potential multi-line scalars
        // In flow context or when parsing explicit keys, be more permissive with multiline
        // In block mapping values, be more conservative
        // Update: Explicit keys should NOT allow multiline - they end at line boundaries
        const allow_multiline = self.in_flow_context and !self.parsing_explicit_key or 
                                (self.mapping_context_indent == null and !self.parsing_explicit_key);
        
        // Special check for invalid multiline implicit keys even when multiline is not allowed
        // This catches cases like HU3P where a plain scalar in a block mapping value
        // would contain mapping indicators on continuation lines
        // But don't apply this check when parsing inside block sequence entries (like JQ4R)
        if (!allow_multiline and !self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek()) and 
            self.mapping_context_indent != null and !self.parsing_explicit_key and 
            !self.parsing_block_sequence_entry) {
            
            var temp_pos = self.lexer.pos;
            temp_pos += 1; // Skip line break
            
            // Skip spaces on new line to find the indent
            while (temp_pos < self.lexer.input.len and self.lexer.input[temp_pos] == ' ') {
                temp_pos += 1;
            }
            
            // Calculate indent of this line
            var line_start = self.lexer.pos + 1;
            while (line_start > 0 and !Lexer.isLineBreak(self.lexer.input[line_start - 1])) {
                line_start -= 1;
            }
            const indent = temp_pos - line_start;
            
            // If this line is indented more than the context and contains mapping indicators, it's invalid
            if (indent > context_indent and temp_pos < self.lexer.input.len and 
                !Lexer.isLineBreak(self.lexer.input[temp_pos])) {
                
                // Check if this line contains a mapping indicator
                var check_pos = temp_pos;
                while (check_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[check_pos])) {
                    if (self.lexer.input[check_pos] == ':' and
                        (check_pos + 1 >= self.lexer.input.len or
                         self.lexer.input[check_pos + 1] == ' ' or
                         Lexer.isLineBreak(self.lexer.input[check_pos + 1]))) {
                        return error.InvalidPlainScalar;
                    }
                    check_pos += 1;
                }
            }
        }
        
        
        if (!self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek()) and allow_multiline) {
            var first_continuation_indent: ?usize = null;
            var comment_interrupted_previous_line = false;
            
            // Check if the current line ends with a comment (before the line break)
            if (self.lexer.pos > 0) {
                var check_pos = self.lexer.pos - 1;
                // Skip back past any trailing whitespace
                while (check_pos > 0 and Lexer.isWhitespace(self.lexer.input[check_pos])) {
                    check_pos -= 1;
                }
                // Check if we ended due to a comment
                if (check_pos > 0 and self.lexer.input[check_pos] == '#') {
                    comment_interrupted_previous_line = true;
                }
            }
            
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
                // But tabs on whitespace-only lines are okay
                if (self.lexer.peek() == '\t' and spaces_count == 0) {
                    // Check if this is a whitespace-only line (tab followed by line break or EOF)
                    const next = self.lexer.peekNext();
                    if (!Lexer.isLineBreak(next) and next != 0) {
                        // There's content after the tab, so this is improper indentation
                        return error.TabsNotAllowed;
                    }
                    // Otherwise, this is a whitespace-only line, which is allowed
                }
                const new_indent = self.lexer.column;
                
                // Check if this line starts with a comment
                if (self.lexer.peek() == '#') {
                    // A comment line interrupts the plain scalar
                    // But we need to check if there are continuation lines after this comment
                    // which would make this an invalid plain scalar pattern
                    
                    // Look ahead to see if there are more indented lines after this comment
                    var temp_pos = self.lexer.pos;
                    // Skip the comment line
                    while (temp_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[temp_pos])) {
                        temp_pos += 1;
                    }
                    // Skip the line break
                    if (temp_pos < self.lexer.input.len and Lexer.isLineBreak(self.lexer.input[temp_pos])) {
                        temp_pos += 1;
                    }
                    
                    // Check if the next line is indented and would be a continuation
                    var next_line_spaces: usize = 0;
                    while (temp_pos < self.lexer.input.len and self.lexer.input[temp_pos] == ' ') {
                        temp_pos += 1;
                        next_line_spaces += 1;
                    }
                    
                    // If the next line is indented more than context and has content, 
                    // this is invalid comment interruption
                    if (temp_pos < self.lexer.input.len and 
                        !Lexer.isLineBreak(self.lexer.input[temp_pos]) and 
                        self.lexer.input[temp_pos] != '#' and
                        next_line_spaces > context_indent) {
                        return error.InvalidPlainScalar;
                    }
                    
                    // Otherwise, comment just ends the scalar
                    self.lexer.pos = line_break_pos;
                    break;
                }
                
                // Check what's on this line
                if (self.lexer.isEOF() or Lexer.isLineBreak(self.lexer.peek())) {
                    // Empty line - continue
                    continue;
                }
                
                
                // For continuation, line must be more indented than the mapping context
                if (new_indent <= context_indent) {
                    // Not a continuation - restore position to before line break
                    self.lexer.pos = line_break_pos;
                    break;
                }
                
                // If a comment interrupted the previous line, continuation is invalid
                if (comment_interrupted_previous_line) {
                    return error.InvalidPlainScalar;
                }
                
                // Check if this continuation line contains a mapping indicator that would
                // make this an invalid multi-line implicit key
                // Skip this check when parsing explicit keys, as they have different rules
                if (!self.parsing_explicit_key) {
                    var check_pos = self.lexer.pos;
                    while (check_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[check_pos])) {
                        if (self.lexer.input[check_pos] == ':' and
                            (check_pos + 1 >= self.lexer.input.len or
                             self.lexer.input[check_pos + 1] == ' ' or
                             Lexer.isLineBreak(self.lexer.input[check_pos + 1]))) {
                            // This continuation line contains a mapping indicator - invalid
                            return error.InvalidPlainScalar;
                        }
                        check_pos += 1;
                    }
                }
                
                // std.debug.print("Debug plain scalar: Continuing line at indent {}\n", .{new_indent});
                
                // If this is the first continuation line, remember its indent
                if (first_continuation_indent == null) {
                    first_continuation_indent = new_indent;
                }
                
                // This line is part of the scalar - consume it
                
                // Now consume the line
                while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                    const ch = self.lexer.peek();
                    if (ch == '#' and self.lexer.input[self.lexer.pos - 1] == ' ') {
                        comment_interrupted_previous_line = true;
                        // Skip to end of line
                        while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                            self.lexer.advanceChar();
                        }
                        break;
                    }
                    
                    
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
            
            // Handle implicit null values (key followed by comma or closing brace)
            var value: *ast.Node = undefined;
            if (self.lexer.peek() == ',' or self.lexer.peek() == '}') {
                // Implicit null value
                value = try self.createNullNode();
            } else if (self.lexer.peek() == ':') {
                // Explicit colon separator
                self.lexer.advanceChar();
                try self.skipWhitespaceAndCommentsInFlow();
                
                if (self.lexer.peek() == ',' or self.lexer.peek() == '}') {
                    value = try self.createNullNode();
                } else {
                    value = try self.parseValue(0) orelse try self.createNullNode();
                }
            } else {
                return error.ExpectedColonOrComma;
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
                
                // Skip whitespace after '-' but validate tab usage
                // Tabs are not allowed before YAML structural indicators 
                // but are allowed before scalar content
                while (self.lexer.peek() == ' ' or self.lexer.peek() == '\t') {
                    if (self.lexer.peek() == '\t') {
                        // Check what follows the tab
                        const next_char = self.lexer.peekNext();
                        // Tab is not allowed before sequence indicators that start new entries
                        // (like standalone '-' followed by whitespace/newline)
                        if (next_char == '-') {
                            // Check if this is a sequence indicator vs part of a scalar
                            const char_after_dash = self.lexer.input[self.lexer.pos + 2];
                            if (char_after_dash == ' ' or char_after_dash == '\t' or 
                                char_after_dash == '\n' or char_after_dash == '\r' or 
                                char_after_dash == 0) {
                                return error.TabsNotAllowed;
                            }
                        }
                        // Other structural indicators
                        if (next_char == '?' or next_char == ':' or 
                            next_char == '{' or next_char == '}' or next_char == '[' or next_char == ']') {
                            return error.TabsNotAllowed;
                        }
                    }
                    self.lexer.advanceChar();
                }
                
                // Set flag to indicate we're parsing a block sequence entry
                const prev_parsing_block_sequence_entry = self.parsing_block_sequence_entry;
                self.parsing_block_sequence_entry = true;
                defer self.parsing_block_sequence_entry = prev_parsing_block_sequence_entry;
                
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
        // std.debug.print("DEBUG: parseBlockMapping called, min_indent={}\n", .{min_indent});
        const node = try self.arena.allocator().create(ast.Node);
        node.* = .{
            .type = .mapping,
            .data = .{ .mapping = .{ .pairs = std.ArrayList(ast.Pair).init(self.arena.allocator()) } },
        };
        
        var mapping_indent: ?usize = null;
        var pending_explicit_key: ?*ast.Node = null;
        
        // Set the mapping context indent for plain scalar validation
        const prev_mapping_context_indent = self.mapping_context_indent;
        self.mapping_context_indent = min_indent;
        defer self.mapping_context_indent = prev_mapping_context_indent;
        
        while (!self.lexer.isEOF()) {
            // Check for tabs before doing any indentation calculations
            try self.checkIndentationForTabs();
            
            // Get current indent - needed by multiple code paths
            const current_indent = self.getCurrentIndent();
            
            var key: ?*ast.Node = null;
            
            // FIRST: Check if we have a pending explicit key waiting for its colon
            // This must be done before indentation checks because the colon line
            // for explicit keys has special indentation rules per YAML spec
            if (pending_explicit_key) |pkey| {
                if (current_indent < min_indent) {
                    break;
                }
                
                // For explicit keys, the colon should be at the same indent as the '?'
                // But we need to be flexible about the mapping_indent tracking
                if (mapping_indent == null) {
                    mapping_indent = current_indent;
                }
            
                // Skip whitespace and comments before looking for the colon
                self.skipWhitespaceAndComments();
                
                if (self.lexer.peek() == ':') {
                    key = pkey;
                    pending_explicit_key = null;
                    self.lexer.advanceChar(); // Skip ':'
                    
                    // Check for tabs after colon
                    if (self.lexer.peek() == '\t') {
                        return error.TabsNotAllowed;
                    }
                } else {
                    // No colon found after explicit key - this means the key has no value (null)
                    key = pkey;
                    pending_explicit_key = null;
                    
                    // Create a null node for the value
                    const null_node = try self.arena.allocator().create(ast.Node);
                    null_node.* = ast.Node{
                        .type = .scalar,
                        .start_line = self.lexer.line,
                        .start_column = self.lexer.column,
                        .data = .{ .scalar = .{ .value = "null", .style = .plain } },
                    };
                    
                    // Add the key-value pair immediately
                    try node.data.mapping.pairs.append(.{ .key = key.?, .value = null_node });
                    key = null; // Reset key to avoid double-processing
                    
                    // Continue to parse the next item without consuming any input
                    continue;
                }
            } else {
                if (current_indent < min_indent) {
                    break;
                }
                
                // If this is not the first pair, check that it's at the same indent
                if (mapping_indent) |map_indent| {
                    if (current_indent != map_indent) {
                        break;
                    }
                } else {
                    // First pair - remember its indent
                    mapping_indent = current_indent;
                }
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
                    
                    // Parse the key - for explicit keys, typically parse as plain scalar
                    // Explicit keys can be complex, but in most cases they're plain scalars
                    const prev_explicit_key = self.parsing_explicit_key;
                    self.parsing_explicit_key = true; // Disable multiline mapping validation
                    defer self.parsing_explicit_key = prev_explicit_key;
                    
                    key = try self.parsePlainScalar();
                    
                    // For explicit keys, the mapping colon can be:
                    // 1. On the same line after spaces: "? key : value"
                    // 2. On the next line: "? key\n: value"
                    // 
                    // In the input "? key:\n:\tkey:", the colon in "key:" is NOT a mapping colon
                    // because it's not preceded by proper separation. We need to find the actual
                    // mapping colon.
                    
                    self.skipSpaces();
                    
                    // Only treat as a mapping colon if it's properly separated with whitespace
                    // A colon immediately after the key (no space) should not be treated as mapping colon
                    const had_whitespace_before_colon = (self.lexer.pos > 0 and 
                        (self.lexer.input[self.lexer.pos - 1] == ' ' or 
                         self.lexer.input[self.lexer.pos - 1] == '\t'));
                    
                    if (self.lexer.peek() == ':' and had_whitespace_before_colon and
                        (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\t' or 
                         self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or 
                         self.lexer.peekNext() == 0)) {
                        // Valid mapping colon on same line  
                        self.lexer.advanceChar(); // Skip ':'
                        
                        // Check for tabs after colon
                        if (self.lexer.peek() == '\t') {
                            return error.TabsNotAllowed;
                        }
                    } else {
                        // The colon is not a proper mapping colon, or mapping colon is on next line
                        // Skip any remaining content on this line and move to next line
                        
                        // Skip to end of current line
                        while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                            self.lexer.advanceChar();
                        }
                        
                        // If we're at EOF, this explicit key has no value - create null value immediately
                        if (self.lexer.isEOF()) {
                            const null_node = try self.arena.allocator().create(ast.Node);
                            null_node.* = ast.Node{
                                .type = .scalar,
                                .start_line = self.lexer.line,
                                .start_column = self.lexer.column,
                                .data = .{ .scalar = .{ .value = "null", .style = .plain } },
                            };
                            
                            // Add the key-value pair immediately
                            try node.data.mapping.pairs.append(.{ .key = key.?, .value = null_node });
                            break; // Exit the loop
                        }
                        
                        // Skip the newline as well
                        if (!self.lexer.isEOF() and Lexer.isLineBreak(self.lexer.peek())) {
                            self.lexer.advanceChar();
                        }
                        
                        pending_explicit_key = key;
                        continue;
                    }
                } else {
                    // Implicit key
                    key = try self.parsePlainScalar();
                    self.skipSpaces();
                    
                    if (self.lexer.peek() != ':') {
                        self.arena.allocator().destroy(key.?);
                        break;
                    }
                    self.lexer.advanceChar();
                    
                    // Check for tabs after colon
                    if (self.lexer.peek() == '\t') {
                        return error.TabsNotAllowed;
                    }
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
                    
                    
                    // After parsing a plain scalar value, check if the next line at the same
                    // indentation as the value contains a mapping indicator, which would
                    // create an invalid multi-line implicit key
                    if (value != null and value.?.type == .scalar and value.?.data.scalar.style == .plain) {
                        const saved_pos = self.lexer.pos;
                        self.skipWhitespaceAndComments();
                        
                        
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
                    'u' => {
                        // Unicode 16-bit escape \uXXXX
                        var hex_chars: [4]u8 = undefined;
                        for (0..4) |i| {
                            if (self.lexer.isEOF()) return error.InvalidHexEscape;
                            hex_chars[i] = self.lexer.peek();
                            if (!Lexer.isHex(hex_chars[i])) return error.InvalidHexEscape;
                            self.lexer.advanceChar();
                        }
                        
                        var value: u16 = 0;
                        for (hex_chars) |hex_char| {
                            value = (value << 4) | @as(u16, hexValue(hex_char));
                        }
                        
                        // Convert Unicode code point to UTF-8
                        if (value <= 0x7F) {
                            try result.append(@as(u8, @intCast(value)));
                        } else if (value <= 0x7FF) {
                            try result.append(@as(u8, @intCast(0xC0 | (value >> 6))));
                            try result.append(@as(u8, @intCast(0x80 | (value & 0x3F))));
                        } else {
                            try result.append(@as(u8, @intCast(0xE0 | (value >> 12))));
                            try result.append(@as(u8, @intCast(0x80 | ((value >> 6) & 0x3F))));
                            try result.append(@as(u8, @intCast(0x80 | (value & 0x3F))));
                        }
                    },
                    'U' => {
                        // Unicode 32-bit escape \UXXXXXXXX
                        var hex_chars: [8]u8 = undefined;
                        for (0..8) |i| {
                            if (self.lexer.isEOF()) return error.InvalidHexEscape;
                            hex_chars[i] = self.lexer.peek();
                            if (!Lexer.isHex(hex_chars[i])) return error.InvalidHexEscape;
                            self.lexer.advanceChar();
                        }
                        
                        var value: u32 = 0;
                        for (hex_chars) |hex_char| {
                            value = (value << 4) | @as(u32, hexValue(hex_char));
                        }
                        
                        // Convert Unicode code point to UTF-8 (simplified for common cases)
                        if (value <= 0x7F) {
                            try result.append(@as(u8, @intCast(value)));
                        } else if (value <= 0x7FF) {
                            try result.append(@as(u8, @intCast(0xC0 | (value >> 6))));
                            try result.append(@as(u8, @intCast(0x80 | (value & 0x3F))));
                        } else if (value <= 0xFFFF) {
                            try result.append(@as(u8, @intCast(0xE0 | (value >> 12))));
                            try result.append(@as(u8, @intCast(0x80 | ((value >> 6) & 0x3F))));
                            try result.append(@as(u8, @intCast(0x80 | (value & 0x3F))));
                        } else if (value <= 0x10FFFF) {
                            try result.append(@as(u8, @intCast(0xF0 | (value >> 18))));
                            try result.append(@as(u8, @intCast(0x80 | ((value >> 12) & 0x3F))));
                            try result.append(@as(u8, @intCast(0x80 | ((value >> 6) & 0x3F))));
                            try result.append(@as(u8, @intCast(0x80 | (value & 0x3F))));
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
                    else => {
                        // Invalid escape sequence - only the specific sequences above are valid in YAML
                        return error.InvalidEscapeSequence;
                    },
                }
            } else if (ch == '\n' or ch == '\r') {
                // Handle line folding in double-quoted strings
                self.lexer.advanceChar();
                if (ch == '\r' and self.lexer.peek() == '\n') {
                    self.lexer.advanceChar();
                }
                
                // Note: Tabs are allowed as indentation in continuation lines of double-quoted strings
                // per YAML spec s-flow-line-prefix(n) which includes s-indent(n)
                
                // Skip leading whitespace on continuation lines (but preserve it as content)
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
    
    fn parseSingleBlockNode(self: *Parser, min_indent: usize) ParseError!?*ast.Node {
        self.skipWhitespaceAndComments();
        
        if (self.lexer.isEOF()) return null;
        
        const ch = self.lexer.peek();
        
        // Flow collections and scalars
        if (ch == '[') return try self.parseFlowSequence();
        if (ch == '{') return try self.parseFlowMapping();
        if (ch == '"') return try self.parseDoubleQuotedScalar();
        if (ch == '\'') return try self.parseSingleQuotedScalar();
        if (ch == '|') return try self.parseLiteralScalar();
        if (ch == '>') return try self.parseFoldedScalar();
        
        // For single node parsing, treat `-` as a sequence entry, not as block sequence start
        if (ch == '-' and (self.lexer.peekNext() == ' ' or self.lexer.peekNext() == '\t' or self.lexer.peekNext() == '\n' or self.lexer.peekNext() == '\r' or self.lexer.peekNext() == 0)) {
            // Parse a single sequence entry
            self.lexer.advanceChar(); // Skip '-'
            try self.skipSpacesCheckTabs();
            
            // Create a sequence with a single entry
            const sequence_node = try self.arena.allocator().create(ast.Node);
            sequence_node.* = ast.Node{
                .type = .sequence,
                .start_line = self.lexer.line,
                .start_column = self.lexer.column,
                .data = .{ .sequence = .{ .items = std.ArrayList(*ast.Node).init(self.arena.allocator()) } },
            };
            
            const entry = try self.parseSingleBlockNode(min_indent) orelse try self.createNullNode();
            try sequence_node.data.sequence.items.append(entry);
            
            return sequence_node;
        }
        
        // Otherwise parse as plain scalar
        if (self.isPlainScalarStart(ch)) {
            return try self.parsePlainScalar();
        }
        
        return null;
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
        if (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
            if (self.lexer.peek() == '#') {
                // Comments must be preceded by whitespace (except at start of line)
                if (self.lexer.pos > 0 and !Lexer.isWhitespace(self.lexer.input[self.lexer.pos - 1]) and self.lexer.column > 1) {
                    return error.InvalidComment;
                }
            } else {
                // Invalid text after block scalar indicator
                return error.InvalidBlockScalar;
            }
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
            // Check for tabs at start of line in literal scalar content
            if (self.lexer.peek() == '\t') {
                return error.TabsNotAllowed;
            }
            
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
                    const char = self.lexer.peek();
                    try result.append(char);
                    self.lexer.advanceChar();
                }
                
                // Tabs on empty lines are allowed, so we don't check line_has_only_tabs anymore
                
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
        if (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
            if (self.lexer.peek() == '#') {
                // Comments must be preceded by whitespace (except at start of line)
                if (self.lexer.pos > 0 and !Lexer.isWhitespace(self.lexer.input[self.lexer.pos - 1]) and self.lexer.column > 1) {
                    return error.InvalidComment;
                }
            } else {
                // Invalid text after block scalar indicator
                return error.InvalidBlockScalar;
            }
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
                    const char = self.lexer.peek();
                    try result.append(char);
                    self.lexer.advanceChar();
                }
                
                // Tabs on empty lines are allowed, so we don't check line_has_only_tabs anymore
                
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
                // Comments must be preceded by whitespace in flow contexts, or be at start of line
                if (self.lexer.pos > 0 and !Lexer.isWhitespace(self.lexer.input[self.lexer.pos - 1]) and 
                    !Lexer.isLineBreak(self.lexer.input[self.lexer.pos - 1])) {
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
        while (self.lexer.peek() == ' ' or self.lexer.peek() == '\t') {
            if (self.lexer.peek() == '\t') {
                return error.TabsNotAllowed;
            }
            self.lexer.advanceChar();
        }
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
                // Tab found in indentation
                // Count it but note that this is typically not allowed
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
        // Don't check tabs on whitespace-only lines or at EOF
        if (self.lexer.isEOF() or Lexer.isLineBreak(self.lexer.peek())) {
            return;
        }
        
        
        const save_pos = self.lexer.pos;
        const save_line = self.lexer.line;
        const save_column = self.lexer.column;
        
        self.lexer.pos = self.lexer.line_start;
        self.lexer.column = 1;
        
        // Check for tabs only in the leading whitespace (indentation) before content
        while (self.lexer.pos < self.lexer.input.len) {
            const ch = self.lexer.peek();
            if (ch == ' ') {
                self.lexer.advanceChar();
            } else if (ch == '\t') {
                // Check if there's any non-whitespace content after this tab on the same line
                var has_content = false;
                var check_pos = self.lexer.pos + 1;
                while (check_pos < self.lexer.input.len and !Lexer.isLineBreak(self.lexer.input[check_pos])) {
                    if (!Lexer.isWhitespace(self.lexer.input[check_pos])) {
                        has_content = true;
                        break;
                    }
                    check_pos += 1;
                }
                
                if (has_content) {
                    // Tab is used as indentation before content - not allowed
                    self.lexer.pos = save_pos;
                    self.lexer.line = save_line;
                    self.lexer.column = save_column;
                    return error.TabsNotAllowed;
                }
                
                // Tab is on a whitespace-only portion, keep checking
                self.lexer.advanceChar();
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
    
    // Multi-document parsing functions
    fn skipDocumentSeparator(self: *Parser) void {
        // Skip document start (---) or end (...) markers
        if (self.lexer.match("---") or self.lexer.match("...")) {
            self.lexer.advance(3);
            
            // Skip any whitespace and comments after the marker
            while (!self.lexer.isEOF()) {
                const ch = self.lexer.peek();
                if (ch == ' ' or ch == '\t') {
                    self.lexer.advanceChar();
                } else if (ch == '#') {
                    // Skip comment to end of line
                    while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek())) {
                        self.lexer.advanceChar();
                    }
                } else if (Lexer.isLineBreak(ch)) {
                    self.lexer.advanceChar();
                    if (ch == '\r' and self.lexer.peek() == '\n') {
                        self.lexer.advanceChar();
                    }
                    break;
                } else {
                    break;
                }
            }
        }
    }
    
    fn isAtDocumentMarker(self: *const Parser) bool {
        return self.lexer.match("---") or self.lexer.match("...");
    }
    
    pub fn parseStream(self: *Parser) ParseError!ast.Stream {
        var stream = ast.Stream.init(self.arena.allocator());
        
        // Skip any leading whitespace and comments
        self.skipWhitespaceAndComments();
        
        while (!self.lexer.isEOF()) {
            // Handle document start marker
            var has_explicit_start = false;
            if (self.lexer.match("---")) {
                has_explicit_start = true;
                self.skipDocumentSeparator();
                self.skipWhitespaceAndComments();
            }
            
            // Check if we have content for a document
            if (self.lexer.isEOF()) break;
            
            // Parse document content
            var document = ast.Document{
                .allocator = self.arena.allocator(),
            };
            
            // Parse directives if this is an explicit document
            if (has_explicit_start) {
                // TODO: Parse directives like %YAML, %TAG if present
            }
            
            // Parse the document content (if any)
            if (!self.lexer.isEOF() and !self.isAtDocumentMarker()) {
                document.root = try self.parseValue(0);
            }
            
            try stream.addDocument(document);
            
            // Skip whitespace and look for document end marker
            self.skipWhitespaceAndComments();
            
            if (self.lexer.match("...")) {
                self.skipDocumentSeparator();
                self.skipWhitespaceAndComments();
            }
            
            // If we're at another document marker or EOF, continue
            if (self.lexer.isEOF() or self.isAtDocumentMarker()) {
                continue;
            }
            
            // If there's more content without explicit markers, it might be another bare document
            // But for now, let's be conservative and stop here
            break;
        }
        
        return stream;
    }
};

pub fn parseStream(input: []const u8) ParseError!ast.Stream {
    var parser = Parser.init(std.heap.page_allocator, input);
    return try parser.parseStream();
}

pub fn parse(input: []const u8) ParseError!ast.Document {
    var parser = Parser.init(std.heap.page_allocator, input);
    
    // Use stream parsing to handle multi-document inputs properly
    const stream = try parser.parseStream();
    
    // For backward compatibility, return the first document if available
    if (stream.documents.items.len > 0) {
        return stream.documents.items[0];
    } else {
        // Return empty document
        return ast.Document{
            .allocator = parser.arena.allocator(),
        };
    }
}