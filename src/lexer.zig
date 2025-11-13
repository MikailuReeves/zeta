const std = @import("std");

const diagnostic = @import("diagnostic.zig");
const TokenType = @import("tokens.zig").TokenType;

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8, // slice of source
    literal: ?[]const u8 = null,
    line: usize,
    column: usize,
};

pub const LexErrorKind = enum {
    UnexpectedChar,
    InvalidNumber,
    UnclosedString,
    UnterminatedBlockComment,
    InvalidEscapeSequence,
    InvalidUtf8,
};

pub const LexError = struct {
    kind: LexErrorKind,
    line: usize,
    column: usize,
    start: usize,
    end: usize,
    lexeme: []const u8,
    offending: ?u8 = null, // for UnexpectedChar
};

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    current_line: usize,
    current_char: usize,
    start_char: usize,
    source: []const u8,
    line_start_indices: std.ArrayList(usize),
    tokens: std.ArrayList(Token),
    errors: std.ArrayList(LexError),
    keyword_map: std.StringHashMap(TokenType),

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Lexer {
        var map = std.StringHashMap(TokenType).init(allocator);

        try map.put("else", .Else);
        try map.put("fun", .Fun);
        try map.put("if", .If);
        try map.put("let", .Let);
        try map.put("return", .Return);
        try map.put("true", .True);
        try map.put("false", .False);
        try map.put("for", .For);
        try map.put("while", .While);
        try map.put("null", .Null);
        try map.put("var", .Var);
        try map.put("print", .Print);
        try map.put("or", .Or);
        try map.put("and", .And);

        var lexer = Lexer{
            .allocator = allocator,
            .current_line = 1,
            .start_char = 0,
            .current_char = 0,
            .source = source,
            .keyword_map = map,
            .line_start_indices = try std.ArrayList(usize).initCapacity(allocator, 16),
            .tokens = try std.ArrayList(Token).initCapacity(allocator, 32),
            .errors = try std.ArrayList(LexError).initCapacity(allocator, 4),
        };

        try lexer.line_start_indices.append(allocator, 0);
        return lexer;
    }

    const LexerError = struct {
        line: usize,
        column: usize,
        message: []const u8,
    };

    pub fn deinit(self: *Lexer) void {
        self.line_start_indices.deinit(self.allocator);
        self.tokens.deinit(self.allocator);
        self.errors.deinit(self.allocator);
    }

    fn addError(self: *Lexer, kind: LexErrorKind, offending: ?u8) !void {
        const start = self.start_char;
        const end = self.current_char;

        try self.errors.append(self.allocator, .{
            .kind = kind,
            .line = self.current_line,
            .column = self.getColumn(),
            .start = start,
            .end = end,
            .lexeme = self.source[start..end],
            .offending = offending,
        });
    }

    fn isAtEnd(self: *const Lexer) bool {
        return self.current_char >= self.source.len;
    }

    // Advance and return the current character while consuming it
    fn advance(self: *Lexer) ?u8 {
        if (self.current_char >= self.source.len) return null;

        const c = self.source[self.current_char];
        self.current_char += 1;
        return c;
    }

    // Peek at the current character without consuming it
    fn peek(self: *Lexer) u8 {
        return if (self.current_char >= self.source.len) 0 else self.source[self.current_char];
    }

    fn peekNext(self: *Lexer) u8 {
        return if (self.current_char + 1 >= self.source.len) 0 else self.source[self.current_char + 1];
    }

    // Add a token to the tokens list
    fn addToken(self: *Lexer, token: TokenType, literal: ?[]const u8) !void {
        try self.tokens.append(self.allocator, Token{
            .kind = token,
            .lexeme = self.source[self.start_char..self.current_char],
            .literal = literal,
            .line = self.current_line,
            .column = self.current_char - self.line_start_indices.items[self.current_line - 1],
        });
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current_char] != expected) return false;

        self.current_char += 1;
        return true;
    }

    fn getColumn(self: *Lexer) usize {
        const line_start = self.line_start_indices.items[self.current_line - 1];
        return self.current_char - line_start;
    }

    fn handleNewline(self: *Lexer) !void {
        self.current_line += 1;
        try self.line_start_indices.append(self.allocator, self.current_char);
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            c == '_';
    }

    fn isHexDigit(c: u8) bool {
        return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }

    fn identifier(self: *Lexer) !void {
        while (isAlphaNumeric(self.peek())) _ = self.advance();

        const text = self.source[self.start_char..self.current_char];
        const token_type = self.keyword_map.get(text) orelse .Identifier;

        try self.addToken(token_type, null);
    }

    // TODO: handle bad floats 123.
    // TODO: bad exponent 1e
    // TODO: hexadecimal
    fn number(self: *Lexer) !void {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();
            while (isDigit(self.peek())) _ = self.advance();
        }

        if (isAlpha(self.peek())) {
            // Consume the rest of the invalid tail
            while (isAlpha(self.peek()) or isDigit(self.peek())) _ = self.advance();

            try self.addError(.InvalidNumber, null);
            return;
        }

        try self.addToken(.Number, self.source[self.start_char..self.current_char]);
    }

    fn string(self: *Lexer) !void {
        const string_start_char = self.start_char;
        const string_start_line = self.current_line;
        const string_start_column = self.getColumn();

        // consume content until we find a closing quote or EOF
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (c == '"') break;

            if (c == '\n') {
                _ = self.advance();
                try self.handleNewline();
            } else {
                _ = self.advance();
            }
        }

        // report error at start of string
        if (self.isAtEnd()) {
            try self.errors.append(self.allocator, .{
                .kind = .UnclosedString,
                .line = string_start_line,
                .column = string_start_column,
                .start = string_start_char,
                .end = self.current_char,
                .lexeme = self.source[string_start_char..self.current_char],
                .offending = null,
            });
            return;
        }

        _ = self.advance(); // closing quote

        // slice inner value without quotes
        const value = self.source[string_start_char + 1 .. self.current_char - 1];
        try self.addToken(.String, value);
    }

    // Scan the next token from the input
    fn scanToken(self: *Lexer) !void {
        self.start_char = self.current_char;
        const c = self.advance() orelse return;
        switch (c) {
            '*' => try self.addToken(.Star, null),
            '/' => { // for "//" comments
                const next_char = self.peek();
                if (next_char == '/') {
                    while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                    return;
                } else if (next_char == '*') {
                    const comment_start_char = self.start_char; // start of "/*"
                    const comment_start_line = self.current_line;
                    const comment_start_column = self.getColumn();

                    _ = self.advance(); // consume '*'

                    while (true) {
                        if (self.peek() == '*' and self.current_char + 1 < self.source.len and self.source[self.current_char + 1] == '/') {
                            _ = self.advance(); // '*'
                            _ = self.advance(); // '/'
                            break;
                        } else if (self.isAtEnd()) {
                            // Use the *comment start* for error coordinates
                            try self.errors.append(self.allocator, .{
                                .kind = .UnterminatedBlockComment,
                                .line = comment_start_line,
                                .column = comment_start_column,
                                .start = comment_start_char,
                                .end = self.current_char,
                                .lexeme = self.source[comment_start_char..self.current_char],
                                .offending = null,
                            });
                            return;
                        } else {
                            if (self.advance() == '\n') try self.handleNewline();
                        }
                    }
                    return;
                }
                try self.addToken(.Slash, null);
            },
            '+' => try self.addToken(.Plus, null),
            '-' => try self.addToken(.Minus, null),
            '{' => try self.addToken(.LBrace, null),
            '}' => try self.addToken(.RBrace, null),
            '(' => try self.addToken(.LParen, null),
            ')' => try self.addToken(.RParen, null),
            ',' => try self.addToken(.Comma, null),
            ';' => try self.addToken(.Semicolon, null),
            '.' => try self.addToken(.Dot, null),
            '!' => if (self.match('=')) try self.addToken(.NotEqual, null) else try self.addToken(.Bang, null),
            '=' => if (self.match('=')) try self.addToken(.Equal, null) else try self.addToken(.Equal, null),
            '<' => if (self.match('=')) try self.addToken(.LessEqual, null) else try self.addToken(.Less, null),
            '>' => if (self.match('=')) try self.addToken(.GreaterEqual, null) else try self.addToken(.Greater, null),
            '"' => try self.string(),
            ' ', '\r', '\t' => {}, // Ignore whitespace
            '\n' => try self.handleNewline(),
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    try self.addError(.UnexpectedChar, c);
                    // you might want to just return here; or advance to try to resync
                }
            },
        }
    }

    pub fn scanTokens(self: *Lexer) ![]Token {
        while (!self.isAtEnd()) {
            try self.scanToken();
        }

        return self.tokens.items;
    }
};
