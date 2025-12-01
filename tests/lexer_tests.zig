const std = @import("std");
const zeta = @import("zeta");

const Lexer = zeta.Lexer;
const TokenType = zeta.Tokens;

test "lexer keyword vs identifier disambiguation" {
    const source = "let letter = 1";
    var lexer = try Lexer.init(std.testing.allocator, source);
    defer lexer.deinit();

    const tokens_slice = try lexer.scanTokens();
    try std.testing.expectEqual(@as(usize, 5), tokens_slice.len);
    try std.testing.expectEqualStrings("let", tokens_slice[0].lexeme);

    try std.testing.expectEqual(TokenType.Identifier, tokens_slice[1].kind);
    try std.testing.expectEqualStrings("letter", tokens_slice[1].lexeme);

    try std.testing.expectEqual(TokenType.Let, tokens_slice[0].kind);
}

test "lexer tokenizes let statement" {
    const source = "let foo = 123";
    var lexer = try Lexer.init(std.testing.allocator, source);
    defer lexer.deinit();

    const tokens_slice = try lexer.scanTokens();
    try std.testing.expectEqual(@as(usize, 5), tokens_slice.len);

    try std.testing.expectEqual(TokenType.Let, tokens_slice[0].kind);
    try std.testing.expectEqualStrings("let", tokens_slice[0].lexeme);

    try std.testing.expectEqual(TokenType.Identifier, tokens_slice[1].kind);
    try std.testing.expectEqualStrings("foo", tokens_slice[1].lexeme);

    try std.testing.expectEqual(TokenType.Equal, tokens_slice[2].kind);
    try std.testing.expectEqualStrings("=", tokens_slice[2].lexeme);

    try std.testing.expectEqual(TokenType.Number, tokens_slice[3].kind);
    try std.testing.expect(tokens_slice[3].literal != null);
    try std.testing.expectEqualStrings("123", tokens_slice[3].literal.?);

    try std.testing.expectEqual(TokenType.Eof, tokens_slice[4].kind);
}

test "single-character tokens" {
    const cases = [_][]const u8{
        "+", "-", "*", "/", "(", ")", "{", "}", ",", ";", ".",
    };

    const expected = [_]TokenType{
        .Plus,   .Minus,  .Star,  .Slash,     .LParen, .RParen,
        .LBrace, .RBrace, .Comma, .Semicolon, .Dot,
    };

    var i: usize = 0;
    while (i < cases.len) : (i += 1) {
        const src = cases[i];
        var lexer = try Lexer.init(std.testing.allocator, src);
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();
        try std.testing.expectEqual(@as(usize, 2), tokens.len);

        // Check primary token
        try std.testing.expectEqual(expected[i], tokens[0].kind);
        try std.testing.expectEqualStrings(src, tokens[0].lexeme);
        try std.testing.expectEqual(@as(usize, 1), tokens[0].line);
        try std.testing.expectEqual(@as(usize, 1), tokens[0].column);

        // Check EOF token
        try std.testing.expectEqual(TokenType.Eof, tokens[1].kind);
        try std.testing.expectEqual(@as(usize, 1), tokens[1].line);
        try std.testing.expectEqual(@as(usize, 1), tokens[1].column);
    }
}

test "multi-character operators" {
    const cases = [_][]const u8{
        "==", "!=", "<=", ">=", "=", "<", ">", "!",
    };

    const expected = [_]TokenType{
        .EqualEqual, .NotEqual, .LessEqual, .GreaterEqual,
        .Equal,      .Less,     .Greater,   .Bang,
    };

    const expected_length = [_]usize{ 2, 2, 2, 2, 1, 1, 1, 1 };

    var i: usize = 0;
    while (i < cases.len) : (i += 1) {
        const src = cases[i];
        var lexer = try Lexer.init(std.testing.allocator, src);
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();
        try std.testing.expectEqual(@as(usize, 2), tokens.len);

        try std.testing.expectEqual(expected[i], tokens[0].kind);
        try std.testing.expectEqualStrings(src, tokens[0].lexeme);

        try std.testing.expectEqual(@as(usize, 1), tokens[0].line);
        try std.testing.expectEqual(@as(usize, expected_length[i]), tokens[0].column);

        try std.testing.expectEqual(TokenType.Eof, tokens[1].kind);
    }
}

test "power operator scanning" {
    // "**"
    {
        var lexer = try Lexer.init(std.testing.allocator, "**");
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();
        try std.testing.expectEqual(TokenType.Power, tokens[0].kind);
        try std.testing.expectEqualStrings("**", tokens[0].lexeme);
        try std.testing.expectEqual(@as(usize, 2), tokens[0].column);
    }

    // "***" → Power, Star
    {
        var lexer = try Lexer.init(std.testing.allocator, "***");
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(TokenType.Power, tokens[0].kind);
        try std.testing.expectEqualStrings("**", tokens[0].lexeme);
        try std.testing.expectEqual(@as(usize, 2), tokens[0].column);

        try std.testing.expectEqual(TokenType.Star, tokens[1].kind);
        try std.testing.expectEqualStrings("*", tokens[1].lexeme);
        try std.testing.expectEqual(@as(usize, 3), tokens[1].column);
    }

    // "****" → Power, Power
    {
        var lexer = try Lexer.init(std.testing.allocator, "****");
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(TokenType.Power, tokens[0].kind);
        try std.testing.expectEqual(TokenType.Power, tokens[1].kind);

        try std.testing.expectEqual(@as(usize, 2), tokens[0].column);
        try std.testing.expectEqual(@as(usize, 4), tokens[1].column);
    }

    // "**+"
    {
        var lexer = try Lexer.init(std.testing.allocator, "**+");
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(TokenType.Power, tokens[0].kind);
        try std.testing.expectEqual(TokenType.Plus, tokens[1].kind);
        try std.testing.expectEqual(@as(usize, 3), tokens[1].column);
    }
}

test "slash behavior: slash vs comments" {
    // "/" produces Slash
    {
        var lexer = try Lexer.init(std.testing.allocator, "/");
        defer lexer.deinit();
        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(TokenType.Slash, tokens[0].kind);
        try std.testing.expectEqualStrings("/", tokens[0].lexeme);
        try std.testing.expectEqual(@as(usize, 1), tokens[0].column);
    }

    // "// comment" produces no Slash token
    {
        var lexer = try Lexer.init(std.testing.allocator, "// hello");
        defer lexer.deinit();
        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(@as(usize, 1), tokens.len);
        try std.testing.expectEqual(TokenType.Eof, tokens[0].kind);
    }

    // "/* ok */" produces no Slash
    {
        var lexer = try Lexer.init(std.testing.allocator, "/* abc */");
        defer lexer.deinit();
        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(@as(usize, 1), tokens.len);
        try std.testing.expectEqual(TokenType.Eof, tokens[0].kind);
    }
}

test "whitespace skipped correctly" {
    // "   +   "
    {
        var lexer = try Lexer.init(std.testing.allocator, "   +   ");
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(TokenType.Plus, tokens[0].kind);
        try std.testing.expectEqualStrings("+", tokens[0].lexeme);

        // "+" at index 3 → current_char=4 → column=4
        try std.testing.expectEqual(@as(usize, 4), tokens[0].column);
    }

    // "\n\t ;"
    {
        var lexer = try Lexer.init(std.testing.allocator, "\n\t ;");
        defer lexer.deinit();

        const tokens = try lexer.scanTokens();

        try std.testing.expectEqual(TokenType.Semicolon, tokens[0].kind);
        try std.testing.expectEqualStrings(";", tokens[0].lexeme);

        // Semicolon at global index 3, but line start index is 1 after newline.
        // column = 4 - 1 = 3? No: index positions:
        // '\n'=0, '\t'=1, ' '=2, ';'=3 → after consuming ";" current_char=4
        // column = current_char(4) - line_start(1) = 3
        try std.testing.expectEqual(@as(usize, 3), tokens[0].column);

        try std.testing.expectEqual(@as(usize, 2), tokens[0].line);
    }
}

test "combined sequence: ()+-*/" {
    var lexer = try Lexer.init(std.testing.allocator, "()+-*/");
    defer lexer.deinit();
    const expected_columns = [_]usize{ 1, 2, 3, 4, 5, 6, 6 }; // eof at the same line.
    const tokens = try lexer.scanTokens();
    try std.testing.expectEqual(@as(usize, 7), tokens.len);

    const expected = [_]TokenType{
        .LParen, .RParen, .Plus, .Minus, .Star, .Slash, .Eof,
    };

    for (expected, 0..) |kind, idx| {
        try std.testing.expectEqual(kind, tokens[idx].kind);
        try std.testing.expectEqual(expected_columns[idx], tokens[idx].column);
    }
}

test "combined sequence: {};,." {
    var lexer = try Lexer.init(std.testing.allocator, "{};,.");
    defer lexer.deinit();
    const expected_columns = [_]usize{ 1, 2, 3, 4, 5, 5 };
    const tokens = try lexer.scanTokens();

    const expected = [_]TokenType{
        .LBrace, .RBrace, .Semicolon, .Comma, .Dot, .Eof,
    };

    for (expected, 0..) |kind, idx| {
        try std.testing.expectEqual(kind, tokens[idx].kind);
        try std.testing.expectEqual(expected_columns[idx], tokens[idx].column);
    }
}
