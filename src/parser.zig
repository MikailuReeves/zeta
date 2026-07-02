// zig fmt: off
const std = @import("std");
const Token = @import("lexer.zig").Token;
const TokenType = @import("tokens.zig").TokenType;
const Node = @import("ast.zig").Node;
const Expr = @import("ast.zig").Expr;
const Allocator = std.mem.Allocator;

const ParseError = error{
    UnexpectedToken,
    OutOfMemory,
    InvalidCharacter,
};

pub const Parser = struct {
    tokens: []const Token,
    current: usize,
    allocator: Allocator,
    last_error_message: ?[]const u8 = null,
    last_error_token: ?Token = null,

    // helpers
    fn peek(self: *const Parser) Token {
        return self.tokens[self.current];
    }

    fn previous(self: *const Parser) Token {
        return self.tokens[self.current - 1];
    }

    fn isAtEnd(self: *const Parser) bool {
        return self.peek().kind == TokenType.Eof;
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) {
            self.current = self.current + 1;
        }
        return self.previous();
    }

    fn check(self: *const Parser, tokenType: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().kind == tokenType;
    }

    fn match(self: *Parser, types: []const TokenType) bool {
        for (types) |token_type| {
            if (self.check(token_type)) {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    fn consume(self: *Parser, tokenType: TokenType, message: []const u8) !Token {
        if (self.check(tokenType)) return self.advance();

        self.last_error_message = message;
        self.last_error_token = self.peek();
        return error.UnexpectedToken;
    }

    // Rules
    fn expression(self: *Parser) ParseError!Node {
        return self.*.equality();
    }

    fn equality(self: *Parser) !Node {
        var left_expr = try self.comparison();

        while (self.match(&.{ .NotEqual, .EqualEqual })) {
            const operator = self.previous();
            const left_ptr = try self.allocator.create(Node);
            left_ptr.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.comparison();

            left_expr = Node{
                .column = operator.column,
                .line = operator.line,
                .expr = .{.binary = .{ .left = left_ptr, .operator = operator.kind, .right = right_ptr }},
            };
        }

        return left_expr;
    }

    fn comparison(self: *Parser) !Node {
        var left_expr = try self.term();

        while (self.match(&.{ .Greater, .GreaterEqual, .Less, .LessEqual })) {
            const operator = self.previous();
            const left_ptr = try self.allocator.create(Node);
            left_ptr.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.term();

            left_expr = Node{
                .column = operator.column,
                .line = operator.line,
                .expr = .{.binary = .{ .left = left_ptr, .operator = operator.kind, .right = right_ptr }},
            };
        }

        return left_expr;
    }

    fn term(self: *Parser) !Node {
        var left_expr = try self.factor();

        while (self.match(&.{ .Minus, .Plus })) {
            const operator = self.previous();
            const left_ptr = try self.allocator.create(Node);
            left_ptr.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.factor();

            left_expr = Node{
                .column = operator.column,
                .line = operator.line,
                .expr = .{.binary = .{ .left = left_ptr, .operator = operator.kind, .right = right_ptr }},
            };
        }

        return left_expr;
    }

    fn factor(self: *Parser) !Node {
        var left_expr = try self.power();

        while (self.match(&.{ .Slash, .Star })) {
            const operator = self.previous();
            const left_ptr = try self.allocator.create(Node);
            left_ptr.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.power();

            left_expr = Node{
                .column = operator.column,
                .line = operator.line,
                .expr = .{.binary = .{ .left = left_ptr, .operator = operator.kind, .right = right_ptr }},
            };
        }

        return left_expr;
    }

    fn power(self: *Parser) !Node {
        const left_expr = try self.unary();

        if(self.match(&.{.Power})) {
            const operator = self.previous();

            const left_prt = try self.allocator.create(Node);
            left_prt.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.power();
            return Node{
              .column = operator.column,
              .line = operator.line,
              .expr = .{.binary = .{ .left = left_prt, .operator = operator.kind, .right = right_ptr}},
            };
        }
        return left_expr;
    }

    fn unary(self: *Parser) !Node {
        if (self.match(&.{ .Bang, .Minus })) {
            const operator = self.previous();
            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.unary();
            return Node{
                .column = operator.column,
                .line = operator.line,
                .expr = .{ .unary = .{ .operator = operator.kind, .operand = right_ptr } }
            };
        }
        return self.primary();
    }

    fn primary(self: *Parser) !Node {
        if (self.match(&.{.False})) {
            const tok = self.previous();
            return Node{
                .line = tok.line,
                .column = tok.column,
                .expr = .{ .literal = .{ .Bool = false } } };
        }
        if (self.match(&.{.True})) {
            const tok = self.previous();
            return Node{
                .line = tok.line,
                .column = tok.column,
                .expr = .{ .literal = .{ .Bool = true } } };
        }
        if (self.match(&.{.Null})) {
            const tok = self.previous();
            return Node{
                .line = tok.line,
                .column = tok.column,
                .expr = .{ .literal = .Null } };
        }

        if (self.match(&.{.Number})) {
            const tok = self.previous();
            const num = try std.fmt.parseFloat(f64, tok.lexeme);
            return Node{
                .column = tok.column,
                .line = tok.line,
                .expr = .{ .literal = .{ .Number = num } } };
        }

        if (self.match(&.{.String})) {
            const tok = self.previous();
            const string = tok.lexeme[1 .. tok.lexeme.len - 1];
            return Node{
                .column = tok.column,
                .line = tok.line,
                .expr = .{ .literal = .{ .String = string } } };
        }

        if (self.match(&.{.LParen})) {
            const expr = try self.expression();
            _ = try self.consume(TokenType.RParen, "Expected ')' after expression");
            return expr;
        }

        return error.UnexpectedToken;
    }

    pub fn parse(self: *Parser) ?Node {
        return self.expression() catch null;
    }
};

test "parser compiles" {
    _ = &Parser.comparison;
    _ = &Parser.primary;
    _ = &Parser.unary;
    _ = &Parser.expression;
    _ = &Parser.consume;
    _ = &Parser.match;
    _ = &Parser.factor;
    _ = &Parser.term;
    _ = &Parser.equality;
}
