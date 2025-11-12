const std = @import("std");

const TokenType = @import("tokens.zig").TokenType;

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8, // slice of source
    literal: ?[]const u8 = null,
    line: usize,
    column: usize,
};

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    current_line: usize,
    current_char: usize,
    start_char: usize,
    source: []const u8,
    line_start_indices: std.ArrayList(usize),
    tokens: std.ArrayList(Token),
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
        };

        try lexer.line_start_indices.append(allocator, 0);
        return lexer;
    }

    pub fn deinit(self: *Lexer) void {
        self.line_start_indices.deinit(self.allocator);
        self.tokens.deinit(self.allocator);
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

    // Match the current character if it equals the expected character
    fn match(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current_char] != expected) return false;

        self.current_char += 1;
        return true;
    }

    fn string(self: *Lexer) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.current_line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            std.debug.print("Unexpected char at line {d}", .{
                self.current_line,
            });
            return;
        }

        _ = self.advance(); // closing "

        // remove the surrounding ""
        const value = self.source[self.start_char + 1 .. self.current_char - 1];
        std.debug.print("{s}\n", .{value});
        try self.addToken(.String, value);
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            c == '_';
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

    fn number(self: *Lexer) !void {
        while (isDigit(self.peek())) _ = self.advance();

        // fractional part
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance(); // consume '.'
            while (isDigit(self.peek())) _ = self.advance();
        }

        // invalid number
        if (isAlpha(self.peek())) {
            std.debug.print("Error at line {d}: invalid numeric literal \n", .{self.current_line});
            while (isAlpha(self.peek()) or isDigit(self.peek())) _ = self.advance();
            return;
        }

        try self.addToken(.Number, self.source[self.start_char..self.current_char]);
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
                    _ = self.advance();
                    while (true) {
                        if (self.peek() == '*' and self.current_char + 1 < self.source.len and self.source[self.current_char + 1] == '/') {
                            _ = self.advance(); // Consume '*'
                            _ = self.advance(); // Consume '/'
                            break;
                        } else if (self.isAtEnd()) {
                            break;
                        } else {
                            if (self.advance() == '\n') {
                                self.current_line += 1;
                                try self.line_start_indices.append(self.allocator, self.current_char);
                            }
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
            '\n' => {
                self.current_line += 1;
                try self.line_start_indices.append(self.allocator, self.current_char);
            },
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    std.debug.print("Unexpected character at line {d}", .{self.current_line});
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
