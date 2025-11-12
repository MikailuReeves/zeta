const std = @import("std");

const TokenType = @import("tokens.zig").TokenType;

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8, // slice of source
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

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !Lexer {
        var lexer = Lexer{
            .allocator = allocator,
            .current_line = 1,
            .start_char = 0,
            .current_char = 0,
            .source = source,
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
    fn peek(self: *const Lexer) ?u8 {
        if (self.isAtEnd()) return null;
        return self.source[self.current_char];
    }

    // Add a token to the tokens list
    fn addToken(self: *Lexer, token: TokenType) !void {
        try self.tokens.append(self.allocator, Token{
            .kind = token,
            .lexeme = self.source[self.start_char..self.current_char],
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

    // Scan the next token from the input
    fn scanToken(self: *Lexer) !void {
        self.start_char = self.current_char;
        const c = self.advance() orelse return;
        switch (c) {
            '*' => try self.addToken(.Star),
            '/' => { // for "//" comments
                const next_char = self.peek();
                if (next_char == '/') {
                    while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                    return;
                }
                try self.addToken(.Slash);
            },
            '+' => try self.addToken(.Plus),
            '-' => try self.addToken(.Minus),
            '{' => try self.addToken(.LBrace),
            '}' => try self.addToken(.RBrace),
            '(' => try self.addToken(.LParen),
            ')' => try self.addToken(.RParen),
            ',' => try self.addToken(.Comma),
            ';' => try self.addToken(.Semicolon),
            '.' => try self.addToken(.Dot),
            '!' => if (self.match('=')) try self.addToken(.NotEqual) else try self.addToken(.Bang),
            '=' => if (self.match('=')) try self.addToken(.Equal) else try self.addToken(.Equal),
            '<' => if (self.match('=')) try self.addToken(.LessEqual) else try self.addToken(.Less),
            '>' => if (self.match('=')) try self.addToken(.GreaterEqual) else try self.addToken(.Greater),
            ' ', '\r', '\t' => {}, // Ignore whitespace
            '\n' => {
                self.current_line += 1;
                try self.line_start_indices.append(self.allocator, self.current_char);
            },
            else => {},
        }
    }

    pub fn scanTokens(self: *Lexer) ![]Token {
        while (!self.isAtEnd()) {
            try self.scanToken();
        }
        return self.tokens.items;
    }
};
