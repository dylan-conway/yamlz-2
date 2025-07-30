const std = @import("std");

pub const Lexer = struct {
    input: []const u8,
    pos: usize = 0,
    line: usize = 1,
    column: usize = 1,
    line_start: usize = 0,
    
    pub fn init(input: []const u8) Lexer {
        return .{ .input = input };
    }
    
    pub fn peek(self: *const Lexer) u8 {
        if (self.pos >= self.input.len) return 0;
        return self.input[self.pos];
    }
    
    pub fn peekNext(self: *const Lexer) u8 {
        if (self.pos + 1 >= self.input.len) return 0;
        return self.input[self.pos + 1];
    }
    
    pub fn peekAt(self: *const Lexer, offset: usize) u8 {
        if (self.pos + offset >= self.input.len) return 0;
        return self.input[self.pos + offset];
    }
    
    pub fn advance(self: *Lexer, count: usize) void {
        var i: usize = 0;
        while (i < count and self.pos < self.input.len) : (i += 1) {
            if (self.input[self.pos] == '\n') {
                self.line += 1;
                self.column = 1;
                self.line_start = self.pos + 1;
            } else {
                self.column += 1;
            }
            self.pos += 1;
        }
    }
    
    pub fn advanceChar(self: *Lexer) void {
        self.advance(1);
    }
    
    pub fn match(self: *const Lexer, str: []const u8) bool {
        if (self.pos + str.len > self.input.len) return false;
        return std.mem.eql(u8, self.input[self.pos..self.pos + str.len], str);
    }
    
    pub fn currentIndent(self: *const Lexer) usize {
        var indent: usize = 0;
        var i = self.line_start;
        while (i < self.input.len and self.input[i] == ' ') : (i += 1) {
            indent += 1;
        }
        return indent;
    }
    
    pub fn isEOF(self: *const Lexer) bool {
        return self.pos >= self.input.len;
    }
    
    pub fn skipWhitespace(self: *Lexer) void {
        while (!self.isEOF() and isWhitespace(self.peek())) {
            self.advanceChar();
        }
    }
    
    pub fn skipSpaces(self: *Lexer) void {
        while (!self.isEOF() and self.peek() == ' ') {
            self.advanceChar();
        }
    }
    
    pub fn skipToEndOfLine(self: *Lexer) void {
        while (!self.isEOF() and !isLineBreak(self.peek())) {
            self.advanceChar();
        }
    }
    
    pub fn skipLineBreak(self: *Lexer) bool {
        const ch = self.peek();
        if (ch == '\r') {
            self.advanceChar();
            if (self.peek() == '\n') {
                self.advanceChar();
            }
            return true;
        } else if (ch == '\n') {
            self.advanceChar();
            return true;
        }
        return false;
    }
    
    pub fn isWhitespace(ch: u8) bool {
        return ch == ' ' or ch == '\t';
    }
    
    pub fn isLineBreak(ch: u8) bool {
        return ch == '\n' or ch == '\r';
    }
    
    pub fn isFlowIndicator(ch: u8) bool {
        return ch == ',' or ch == '[' or ch == ']' or ch == '{' or ch == '}';
    }
    
    pub fn isIndicator(ch: u8) bool {
        return switch (ch) {
            '-', '?', ':', ',', '[', ']', '{', '}', '#', '&', '*', '!', '|', '>', '\'', '"', '%', '@', '`' => true,
            else => false,
        };
    }
    
    pub fn isNonSpace(ch: u8) bool {
        return !isWhitespace(ch) and !isLineBreak(ch) and ch != 0;
    }
    
    pub fn isAlphaNumeric(ch: u8) bool {
        return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9');
    }
    
    pub fn isAnchorChar(ch: u8) bool {
        return isAlphaNumeric(ch) or ch == '_' or ch == '-';
    }
    
    pub fn isHex(ch: u8) bool {
        return (ch >= '0' and ch <= '9') or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <= 'F');
    }
    
    pub fn isDecimal(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }
    
    pub fn isSafeFirst(ch: u8) bool {
        return !isIndicator(ch) or ch == '-' or ch == '?' or ch == ':';
    }
    
    pub fn isSafe(ch: u8) bool {
        return ch != 0 and !isFlowIndicator(ch);
    }
};