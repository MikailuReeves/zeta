pub const TokenType = enum {
    // Operators
    Star,
    Slash,
    Plus,
    Minus,
    Bang,
    Power,

    // Comparison
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    Equal,
    EqualEqual,
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
    Or,
    And,

    // Special
    Eof,

    // Literals
    Identifier,
    Number,
    String,
};
