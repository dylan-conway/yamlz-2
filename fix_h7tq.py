#!/usr/bin/env python3
import re

# Read the file
with open('src/parser.zig', 'r') as f:
    content = f.read()

# 1. First, add the parseDirective function before parseValue
parseDirective_func = '''    
    fn parseDirective(self: *Parser) ParseError!void {
        // We're at a '%' character
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
            
            // Check for extra content after version (should only be comment or line end)
            if (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and self.lexer.peek() != '#') {
                // Extra content after YAML version - error
                return error.InvalidDirective;
            }
            
            const version = self.lexer.input[version_start..version_end];
            
            // Support both YAML 1.1 and 1.2
            if (!std.mem.eql(u8, version, "1.1") and !std.mem.eql(u8, version, "1.2")) {
                return error.UnsupportedYamlVersion;
            }
        } else if (std.mem.eql(u8, directive_name, "TAG")) {
            // Parse TAG directive
            // Skip whitespace to tag handle
            while (!self.lexer.isEOF() and Lexer.isWhitespace(self.lexer.peek())) {
                self.lexer.advanceChar();
            }
            
            // Parse tag handle (e.g., !e!)
            const handle_start = self.lexer.pos;
            if (self.lexer.peek() == '!') {
                self.lexer.advanceChar(); // First !
                // Parse handle characters
                while (!self.lexer.isEOF() and !Lexer.isWhitespace(self.lexer.peek()) and self.lexer.peek() != '!') {
                    self.lexer.advanceChar();
                }
                if (self.lexer.peek() == '!') {
                    self.lexer.advanceChar(); // Closing !
                }
            }
            const handle = self.lexer.input[handle_start..self.lexer.pos];
            
            // Skip whitespace to prefix
            while (!self.lexer.isEOF() and Lexer.isWhitespace(self.lexer.peek())) {
                self.lexer.advanceChar();
            }
            
            // Parse tag prefix (URI)
            const prefix_start = self.lexer.pos;
            while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and !Lexer.isWhitespace(self.lexer.peek()) and self.lexer.peek() != '#') {
                self.lexer.advanceChar();
            }
            const prefix = self.lexer.input[prefix_start..self.lexer.pos];
            
            // Store the tag handle mapping
            try self.tag_handles.put(handle, prefix);
        } else {
            // Unknown directive - skip it with a warning (not an error)
            // Already at end of directive name, just skip rest of line
        }
        
        // Skip to end of line
        self.lexer.skipToEndOfLine();
        _ = self.lexer.skipLineBreak();
    }
'''

# Insert parseDirective before parseValue
insertion_point = "    fn parseValue(self: *Parser, min_indent: usize) ParseError!?*ast.Node {"
content = content.replace(insertion_point, parseDirective_func + "\n" + insertion_point)

# 2. Now update parseDocument to use parseDirective
# Find and replace the directive parsing block in parseDocument
old_block = '''            // Check for directive
            if (self.lexer.peek() == '%') {
                // Directives are not allowed after document content
                if (self.has_document_content) {
                    return error.DirectiveAfterContent;
                }
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
                    
                    // Check for extra content after version (should only be comment or line end)
                    if (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and self.lexer.peek() != '#') {
                        // Extra content after YAML version - error
                        return error.InvalidDirective;
                    }
                    
                    const version = self.lexer.input[version_start..version_end];
                    
                    // Support both YAML 1.1 and 1.2
                    if (!std.mem.eql(u8, version, "1.1") and !std.mem.eql(u8, version, "1.2")) {
                        return error.UnsupportedYamlVersion;
                    }
                } else if (std.mem.eql(u8, directive_name, "TAG")) {
                    // Parse TAG directive
                    // Skip whitespace to tag handle
                    while (!self.lexer.isEOF() and Lexer.isWhitespace(self.lexer.peek())) {
                        self.lexer.advanceChar();
                    }
                    
                    // Parse tag handle (e.g., !e!)
                    const handle_start = self.lexer.pos;
                    if (self.lexer.peek() == '!') {
                        self.lexer.advanceChar(); // First !
                        // Parse handle characters
                        while (!self.lexer.isEOF() and !Lexer.isWhitespace(self.lexer.peek()) and self.lexer.peek() != '!') {
                            self.lexer.advanceChar();
                        }
                        if (self.lexer.peek() == '!') {
                            self.lexer.advanceChar(); // Closing !
                        }
                    }
                    const handle = self.lexer.input[handle_start..self.lexer.pos];
                    
                    // Skip whitespace to prefix
                    while (!self.lexer.isEOF() and Lexer.isWhitespace(self.lexer.peek())) {
                        self.lexer.advanceChar();
                    }
                    
                    // Parse tag prefix (URI)
                    const prefix_start = self.lexer.pos;
                    while (!self.lexer.isEOF() and !Lexer.isLineBreak(self.lexer.peek()) and !Lexer.isWhitespace(self.lexer.peek()) and self.lexer.peek() != '#') {
                        self.lexer.advanceChar();
                    }
                    const prefix = self.lexer.input[prefix_start..self.lexer.pos];
                    
                    // Store the tag handle mapping
                    try self.tag_handles.put(handle, prefix);
                } else {
                    // Unknown directive - skip it with a warning (not an error)
                    self.lexer.skipToEndOfLine();
                }
                
                // Skip to end of line
                self.lexer.skipToEndOfLine();
                _ = self.lexer.skipLineBreak();
                self.skipWhitespaceAndComments();'''

new_block = '''            // Check for directive
            if (self.lexer.peek() == '%') {
                // Directives are not allowed after document content
                if (self.has_document_content) {
                    return error.DirectiveAfterContent;
                }
                try self.parseDirective();
                self.skipWhitespaceAndComments();'''

content = content.replace(old_block, new_block)

# Write the file back
with open('src/parser.zig', 'w') as f:
    f.write(content)

print("Fixed parser.zig - parseDirective function added and parseDocument updated to use it")