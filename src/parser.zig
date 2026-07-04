// zig fmt: off
const std = @import("std");
const Token = @import("lexer.zig").Token;
const TokenType = @import("tokens.zig").TokenType;
const Node = @import("ast.zig").Node;
const Expr = @import("ast.zig").Expr;
const Decl = @import("ast.zig").Decl;
const Allocator = std.mem.Allocator;

const ParseError = error{
    UnexpectedToken,
    OutOfMemory,
    InvalidCharacter,
    ParserError,
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
        return self.assignment();
    }

    fn assignment(self: *Parser) !Node {
        const expr = try self.or_();

        if (self.match(&.{.Equal})) {
            const equals = self.previous();
            const value_expr = try self.assignment();
            const value_ptr = try self.allocator.create(Node);
            value_ptr.* = value_expr;


            switch (expr.expr) {
                .identifier => |name| {
                    return Node{
                        .column = expr.column,
                        .line = expr.line,
                        .expr = .{ .assign = .{ .name = name, .value = value_ptr } }
                    };
                },
                else => {
                    self.last_error_message = "Invalid assignment target,";
                    self.last_error_token = equals;
                    return error.UnexpectedToken;
                }
            }
        }
        return expr;
    }

    fn or_(self: *Parser) !Node {
        var left_expr = try self.and_();

        while (self.match(&.{ .Or })) {
            const operator = self.previous();
            const left_ptr = try self.allocator.create(Node);
            left_ptr.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.and_();

            left_expr = Node{
                .column = operator.column,
                .line = operator.line,
                .expr = .{ .logical = .{ .left = left_ptr, .operator = operator.kind,.right = right_ptr } }
            };
        }
        return left_expr;
    }

    fn and_(self: *Parser) !Node {
        var left_expr = try self.equality();

        while (self.match(&.{ .And })) {
            const operator = self.previous();
            const left_ptr = try self.allocator.create(Node);
            left_ptr.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.equality();

            left_expr = Node{
                .column = operator.column,
                .line = operator.line,
                .expr = .{ .logical = .{ .left = left_ptr, .operator = operator.kind,.right = right_ptr } }
            };
        }
        return left_expr;
    }

    fn declaration(self: *Parser) ParseError!Decl {
        if (self.match(&.{.Var})) {
            return self.varDeclaration();
        }
        return self.statement();
    }

    fn varDeclaration(self: *Parser) !Decl {
        const name = try self.consume(.Identifier, "Expected a variable name");

        var initializer : ?Node = null;
        if (self.match(&.{.Equal})) {
            initializer = try self.expression();
        }
        _ =try self.consume(.Semicolon, "Expect ';' after variable declaration.");
        return Decl{.var_statement = .{
            .name = name.lexeme,
            .var_expression = initializer }};
    }

    fn whileStatement(self: *Parser) ParseError!Decl {
        _ = try self.consume(.LParen, "Expected '(' after while.");
        const condition = try self.expression();
        _ = try self.consume(.RParen, "Expected ')' after while condition");

        const body = try self.allocator.create(Decl);
        body.* = try self.statement();

        return Decl {.while_statement = .{
            .condition = condition,
            .body = body,
        }};
    }

    fn statement(self: *Parser) !Decl {
        if (self.match(&.{.If})) {
            return try self.ifStatement();
        } else if (self.match(&.{.LBrace})) {
            return Decl{.block = try self.block()};
        } else if (self.match(&.{.Print})) {
            return try self.printStatement();
        } else if (self.match(&.{.While})) {
            return try self.whileStatement();
        } else if (self.match(&.{.For})) {
            return try self.forStatement();
        }
        return self.expressionStatement();
    }

    fn forStatement(self: *Parser) ParseError!Decl {
        _ = try self.consume(.LParen, "Expected '(' after 'for'.");

        var initializer: ?Decl = null;

        if (self.match(&.{.Semicolon})) {
            // no initializer, already null
        } else if (self.match(&.{.Var})) {
            initializer = try self.varDeclaration();
        } else {
            initializer = try self.expressionStatement();
        }

        var condition: ?Node = null;
        if (!(self.check(.Semicolon))) {
            condition = try self.expression();
        }
        _ = try self.consume(.Semicolon, "Expect ';' after loop condition.");

        var increment: ?Node = null;
        if (!(self.check(.RParen))) {
            increment = try self.expression();
        }
        _ = try self.consume(.RParen, "Expected ')' after for clauses");

        var body = try self.statement();

        if (increment) |inc| {
            const stmts = try self.allocator.alloc(Decl, 2);
            stmts[0] = body;
            stmts[1] = Decl{.expr_statement = inc};
            body = Decl{ .block = stmts };
        }

        if (condition == null) {
            condition = Node{
                .column = 0,
                .line = 0,
                .expr = .{ .literal = .{ .Bool = true } }
            };
        }

        const body_ptr = try self.allocator.create(Decl);
        body_ptr.* = body;
        body = Decl{ .while_statement = .{ .body = body_ptr, .condition = condition.? } };

        if (initializer) |init| {
            const stmts = try self.allocator.alloc(Decl, 2);
            stmts[0] = init;
            stmts[1] = body;
            body = Decl{ .block = stmts };
        }

        return body;
    }

    fn expressionStatement(self: *Parser) !Decl {
        const expr = try self.expression();
        _ =try self.consume(.Semicolon, "Expect ';' after expression.");
        return Decl{.expr_statement = expr};
    }

    fn printStatement(self: *Parser) !Decl {
        const value = try self.expression();
        _ =try self.consume(.Semicolon, "Expect ';' after value.");
        return Decl{.print_statement = value};
    }

    fn ifStatement(self: *Parser) ParseError!Decl {
        _ = try self.consume(.LParen, "Expect '(' after 'if'.");
        const condition = try self.expression();
        _ = try self.consume(.RParen, "Expect ')' after if condition.");

        const then_branch = try self.allocator.create(Decl);
        then_branch.* = try self.statement();

        var else_branch: ?*Decl = null;

        if (self.match(&.{.Else})) {
            else_branch = try self.allocator.create(Decl);
            else_branch.?.* = try self.statement();
        }

        return Decl {.if_statement = .{
            .condition = condition,
            .else_branch = else_branch,
            .then_branch = then_branch }};
    }

    fn block(self: *Parser) ![]Decl {
        var statements: std.ArrayList(Decl) = .empty;
        while(!self.check(.RBrace) and !self.isAtEnd()) {
            const decl = try self.declaration();
            try statements.append(self.allocator, decl);
        }
        _ = try self.consume(.RBrace,  "Expect '}' after block.");
        return statements.toOwnedSlice(self.allocator);
    }


    fn equality(self: *Parser) !Node {
        var left_expr = try self.comparison();

        while (self.match(&.{ .NotEqual, .EqualEqual })) {
            const operator = self.previous();
            const left_ptr = try self.allocator.create(Node);
            left_ptr.* = left_expr;

            const right_ptr = try self.allocator.create(Node);
            right_ptr.* = try self.comparison();

            if (operator.kind == TokenType.EqualEqual) {
                left_expr = Node{
                    .column = operator.column,
                    .line = operator.line,
                    .expr = .{.binary = .{ .left = left_ptr, .operator = operator.kind, .right = right_ptr }},
                };
            } else {
                const left_expr_ptr = try self.allocator.create(Node);
                left_expr = Node{
                    .column = operator.column,
                    .line = operator.line,
                    .expr = .{.binary = .{ .left = left_ptr, .operator = .EqualEqual, .right = right_ptr }},
                };
                left_expr_ptr.* = left_expr;

                left_expr = Node {
                  .column = operator.column,
                  .line = operator.line,
                  .expr = .{ .unary = .{ .operator = .Bang, .operand = left_expr_ptr} }
                };
            }
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

            switch (operator.kind) {
                .Greater => {
                    left_expr = Node{
                        .column = operator.column,
                        .line = operator.line,
                        .expr = .{.binary = .{ .left = right_ptr, .operator = .Less, .right = left_ptr }},
                    };
                },
                .GreaterEqual => {
                    const inner_ptr = try self.allocator.create(Node);
                    inner_ptr.* = Node{
                        .column = operator.column,
                        .line = operator.line,
                        .expr = .{.binary = .{ .left = left_ptr, .operator = .Less, .right = right_ptr }},
                    };

                    left_expr = Node{
                        .column = operator.column,
                        .line = operator.line,
                        .expr = .{ .unary = .{ .operator = .Bang, .operand = inner_ptr } },
                    };
                },
                .LessEqual => {
                    const inner_ptr = try self.allocator.create(Node);
                    inner_ptr.* = Node{
                        .column = operator.column,
                        .line = operator.line,
                        .expr = .{.binary = .{ .left = right_ptr, .operator = .Less, .right = left_ptr }},
                    };

                    left_expr = Node{
                        .column = operator.column,
                        .line = operator.line,
                        .expr = .{ .unary = .{ .operator = .Bang, .operand = inner_ptr } },
                    };
                },
                .Less => {
                    left_expr = Node{
                        .column = operator.column,
                        .line = operator.line,
                        .expr = .{ .binary = .{ .left = left_ptr, .operator = .Less, .right = right_ptr } },
                    };
                },
                else => unreachable,
            }
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

        if (self.match(&.{.Identifier})) {
            const tok = self.previous();
            return Node{
                .column = tok.column,
                .line = tok.line,
                .expr = .{ .identifier = tok.lexeme }
            };
        }

        return error.UnexpectedToken;
    }

    pub fn parse(self: *Parser) ![]Decl {
        var declarations: std.ArrayList(Decl) = .empty;
        while(!self.isAtEnd()) {
            const decl = try self.declaration();
            try declarations.append(self.allocator, decl);
        }
        return declarations.toOwnedSlice(self.allocator);
    }
};

test "parser compiles" {
    _ = &Parser.statement;
    _ = &Parser.declaration;
    _ = &Parser.expressionStatement;
    _ = &Parser.varDeclaration;
    _ = &Parser.comparison;
    _ = &Parser.primary;
    _ = &Parser.unary;
    _ = &Parser.expression;
    _ = &Parser.consume;
    _ = &Parser.match;
    _ = &Parser.factor;
    _ = &Parser.term;
    _ = &Parser.equality;
    _ = &Parser.assignment;
    _ = &Parser.block;
    _ = &Parser.or_;
    _ = &Parser.and_;
}
