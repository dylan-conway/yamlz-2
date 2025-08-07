                    self.lexer.skipToEndOfLine();
                    _ = self.lexer.skipLineBreak();
                    self.skipWhitespaceAndComments();
                } else {
                    // Parse document content
                    self.has_document_content = true;
                    document.root = try self.parseValue(0);
                    
                    // After parsing the root value, check for unexpected content
                    self.skipWhitespaceAndComments();
                    // After parsing root value, check if there's unexpected content
                    if (!self.lexer.isEOF() and !self.isAtDocumentMarker()) {
                        const ch = self.lexer.peek();
                        // Check for extra flow collection delimiters
                        if (ch == ']' or ch == '}') {
                            return error.UnexpectedCharacter;
                        }
                    }
                    
                    break; // Only parse one value per document
                }
            }
            
            try stream.addDocument(document);
            
            // Check for document end marker first
            if (self.lexer.match("...")) {
                self.skipDocumentSeparator();
            }
            
            // Skip whitespace and comments but preserve document markers
            self.skipWhitespaceAndCommentsButNotDocumentMarkers();
            
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
    // Create parser on heap to keep arena alive
    const parser_ptr = try std.heap.page_allocator.create(Parser);
    parser_ptr.* = try Parser.init(std.heap.page_allocator, input);
    // Don't deinit the parser - the arena owns the memory
    return try parser_ptr.parseStream();
}

pub fn parse(input: []const u8) ParseError!ast.Document {
    // Create parser on heap to keep arena alive
    const parser_ptr = try std.heap.page_allocator.create(Parser);
    parser_ptr.* = try Parser.init(std.heap.page_allocator, input);
    // Don't deinit the parser - the arena owns the memory and we need it to stay alive
    
    // Use stream parsing to handle multi-document inputs properly
    const stream = try parser_ptr.parseStream();
    
    // For backward compatibility, return the first document if available
    if (stream.documents.items.len > 0) {
        return stream.documents.items[0];
    } else {
        // Return empty document
        return ast.Document{
            .allocator = parser_ptr.arena.allocator(),
        };
    }
}