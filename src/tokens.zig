pub const TokenType = enum {
    // Operators
    Star,
    Slash,
    Plus,
    Minus,
    Bang,

    // Comparison
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    Equal,
    NotEqual,

    // Delimiters
    Comma,
    Semicolon,
    Dot,

    // Groups
    LBrace,
    RBrace,
    LParen,
    RParen,

    // Keywords
    Else,
    Fun,
    If,
    Let,
    Return,
    True,
    False,
    For,
    While,
    Null,
    Var,
    Print,

    // Special
    Eof,

    // Literals
    Identifier,
    Number,
    String,
};
